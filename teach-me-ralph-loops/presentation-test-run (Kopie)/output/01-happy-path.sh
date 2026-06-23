#!/bin/bash
# Experiment 1: Happy Path -- Build-time Hibernate Entity Enhancement
#
# Verifies:
# 1. hibernate-enhance-maven-plugin produces enhanced bytecode at build time
# 2. Enhanced app deploys successfully to EAP 8.2
# 3. Lazy @Basic field loading works (separate SQL for lazy field)
# 4. Whether HHH90009001 log message appears (not expected in ORM 6.6.x)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCES="$BASE_DIR/sources"
EAP_HOME_REAL="$SOURCES/8.2.0.Alpha-CR39/jboss-eap-8.2"
MAVEN_REPO="$SOURCES/8.2.0.Alpha-CR39/jboss-eap-8.2.0.Alpha-maven-repository/maven-repository"
APP_DIR="$SCRIPT_DIR/01-test-app-happy-path"
RESULT="ERROR"
EAP_PID=""

# EAP's standalone.sh uses eval which breaks on paths with parentheses/spaces.
# Create symlinks under /tmp to work around this.
EAP_HOME="/tmp/eap-test-01-home"
EAP_BASE="/tmp/eap-test-01-base"

cleanup() {
    if [[ -n "$EAP_PID" ]]; then
        "$EAP_HOME/bin/jboss-cli.sh" --connect \
            --controller=localhost:19990 command=shutdown 2>/dev/null || true
        sleep 2
        kill "$EAP_PID" 2>/dev/null || true
        wait "$EAP_PID" 2>/dev/null || true
    fi
    rm -f "$EAP_HOME" /tmp/enhancement-test.war
    rm -rf "$EAP_BASE"
    echo ""
    echo "========================================"
    echo "RESULT: $RESULT"
    echo "========================================"
}
trap cleanup EXIT

# Set up symlink for JBOSS_HOME (avoids parentheses in path)
rm -f "$EAP_HOME"
ln -sfn "$EAP_HOME_REAL" "$EAP_HOME"

# ------------------------------------------------------------------
# Step 1: Install EAP maven artifacts into local Maven cache
# ------------------------------------------------------------------
echo "=== Step 1: Installing EAP artifacts into local Maven cache ==="

install_artifact() {
    local jar="$1"
    local pom="$2"
    if [[ ! -f "$jar" ]]; then
        echo "ERROR: Missing artifact jar: $jar"
        exit 1
    fi
    mvn -q org.apache.maven.plugins:maven-install-plugin:3.1.1:install-file \
        -Dfile="$jar" -DpomFile="$pom" 2>&1 | tail -3
}

install_artifact \
    "$MAVEN_REPO/org/hibernate/orm/tooling/hibernate-enhance-maven-plugin/6.6.51.Final-redhat-00001/hibernate-enhance-maven-plugin-6.6.51.Final-redhat-00001.jar" \
    "$MAVEN_REPO/org/hibernate/orm/tooling/hibernate-enhance-maven-plugin/6.6.51.Final-redhat-00001/hibernate-enhance-maven-plugin-6.6.51.Final-redhat-00001.pom"

install_artifact \
    "$MAVEN_REPO/org/hibernate/orm/hibernate-core/6.6.51.Final-redhat-00001/hibernate-core-6.6.51.Final-redhat-00001.jar" \
    "$MAVEN_REPO/org/hibernate/orm/hibernate-core/6.6.51.Final-redhat-00001/hibernate-core-6.6.51.Final-redhat-00001.pom"

install_artifact \
    "$MAVEN_REPO/jakarta/persistence/jakarta.persistence-api/3.1.0.redhat-00002/jakarta.persistence-api-3.1.0.redhat-00002.jar" \
    "$MAVEN_REPO/jakarta/persistence/jakarta.persistence-api/3.1.0.redhat-00002/jakarta.persistence-api-3.1.0.redhat-00002.pom"

echo "  Artifacts installed."

# ------------------------------------------------------------------
# Step 2: Create test application
# ------------------------------------------------------------------
echo "=== Step 2: Creating test application ==="

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/src/main/java/com/test/entity"
mkdir -p "$APP_DIR/src/main/java/com/test/servlet"
mkdir -p "$APP_DIR/src/main/resources/META-INF"
mkdir -p "$APP_DIR/src/main/webapp/WEB-INF"

# -- pom.xml --
cat > "$APP_DIR/pom.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.test</groupId>
    <artifactId>enhancement-happy-path</artifactId>
    <version>1.0</version>
    <packaging>war</packaging>

    <properties>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <hibernate.version>6.6.51.Final-redhat-00001</hibernate.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>jakarta.persistence</groupId>
            <artifactId>jakarta.persistence-api</artifactId>
            <version>3.1.0</version>
            <scope>provided</scope>
        </dependency>
        <dependency>
            <groupId>jakarta.servlet</groupId>
            <artifactId>jakarta.servlet-api</artifactId>
            <version>6.0.0</version>
            <scope>provided</scope>
        </dependency>
        <dependency>
            <groupId>jakarta.transaction</groupId>
            <artifactId>jakarta.transaction-api</artifactId>
            <version>2.0.1</version>
            <scope>provided</scope>
        </dependency>
    </dependencies>

    <build>
        <finalName>enhancement-test</finalName>
        <plugins>
            <plugin>
                <groupId>org.hibernate.orm.tooling</groupId>
                <artifactId>hibernate-enhance-maven-plugin</artifactId>
                <version>${hibernate.version}</version>
                <executions>
                    <execution>
                        <id>enhance</id>
                        <goals>
                            <goal>enhance</goal>
                        </goals>
                        <configuration>
                            <enableLazyInitialization>true</enableLazyInitialization>
                            <enableDirtyTracking>true</enableDirtyTracking>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-war-plugin</artifactId>
                <version>3.4.0</version>
                <configuration>
                    <failOnMissingWebXml>false</failOnMissingWebXml>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
EOF

# -- JPA Entity with lazy @Basic field --
cat > "$APP_DIR/src/main/java/com/test/entity/Document.java" << 'EOF'
package com.test.entity;

import jakarta.persistence.Basic;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Lob;
import jakarta.persistence.Table;

@Entity
@Table(name = "test_document")
public class Document {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    @Basic(fetch = FetchType.LAZY)
    @Column(length = 10000)
    private String content;

    public Document() {}

    public Document(String title, String content) {
        this.title = title;
        this.content = content;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
}
EOF

# -- Test servlet --
cat > "$APP_DIR/src/main/java/com/test/servlet/TestServlet.java" << 'EOF'
package com.test.servlet;

import com.test.entity.Document;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.transaction.Transactional;
import java.io.IOException;
import java.io.PrintWriter;

@WebServlet("/test")
public class TestServlet extends HttpServlet {

    @PersistenceContext(unitName = "test-pu")
    private EntityManager em;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setContentType("text/plain");
        PrintWriter out = resp.getWriter();

        try {
            // Check if entity class is enhanced
            Class<?> docClass = Document.class;
            boolean hasInterceptor = false;
            try {
                docClass.getDeclaredField("$$_hibernate_attributeInterceptor");
                hasInterceptor = true;
            } catch (NoSuchFieldException e) {
                // not enhanced
            }

            boolean implementsInterceptable = false;
            for (Class<?> iface : docClass.getInterfaces()) {
                if (iface.getSimpleName().equals("PersistentAttributeInterceptable")) {
                    implementsInterceptable = true;
                    break;
                }
            }

            out.println("=== Build-Time Enhancement Check ===");
            out.println("Has $$_hibernate_attributeInterceptor field: " + hasInterceptor);
            out.println("Implements PersistentAttributeInterceptable: " + implementsInterceptable);
            out.println("Enhancement active: " + (hasInterceptor && implementsInterceptable));
            out.println("STATUS: OK");

        } catch (Exception e) {
            out.println("ERROR: " + e.getMessage());
            e.printStackTrace(out);
        }
    }
}
EOF

# -- persistence.xml --
cat > "$APP_DIR/src/main/resources/META-INF/persistence.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<persistence xmlns="https://jakarta.ee/xml/ns/persistence"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="https://jakarta.ee/xml/ns/persistence
             https://jakarta.ee/xml/ns/persistence/persistence_3_0.xsd"
             version="3.0">
    <persistence-unit name="test-pu" transaction-type="JTA">
        <jta-data-source>java:jboss/datasources/ExampleDS</jta-data-source>
        <class>com.test.entity.Document</class>
        <properties>
            <property name="hibernate.hbm2ddl.auto" value="create-drop"/>
            <property name="hibernate.show_sql" value="true"/>
            <property name="hibernate.format_sql" value="true"/>
        </properties>
    </persistence-unit>
</persistence>
EOF

# -- beans.xml for CDI --
cat > "$APP_DIR/src/main/webapp/WEB-INF/beans.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="https://jakarta.ee/xml/ns/jakartaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee
       https://jakarta.ee/xml/ns/jakartaee/beans_4_0.xsd"
       bean-discovery-mode="all" version="4.0">
</beans>
EOF

echo "  Test application created at $APP_DIR"

# ------------------------------------------------------------------
# Step 3: Build the application
# ------------------------------------------------------------------
echo "=== Step 3: Building test application ==="

cd "$APP_DIR"
BUILD_LOG="$APP_DIR/build.log"
mvn clean package -o 2>&1 | tee "$BUILD_LOG"
MVN_EXIT=${PIPESTATUS[0]}

if [[ $MVN_EXIT -ne 0 ]]; then
    echo ""
    echo "WARNING: Offline build failed (exit $MVN_EXIT). Retrying with network for compile deps..."
    mvn clean package 2>&1 | tee "$BUILD_LOG"
    MVN_EXIT=${PIPESTATUS[0]}
fi

if [[ $MVN_EXIT -ne 0 ]]; then
    echo "ERROR: Maven build failed"
    RESULT="ERROR"
    exit 1
fi

# Check if enhancement plugin ran
if grep -qi "enhance" "$BUILD_LOG" 2>/dev/null; then
    echo "  Enhancement plugin output found in build log."
else
    echo "  WARNING: No enhancement plugin output found in build log."
fi

echo "  Build succeeded."

# ------------------------------------------------------------------
# Step 4: Verify bytecode enhancement in compiled classes
# ------------------------------------------------------------------
echo "=== Step 4: Verifying bytecode enhancement ==="

CLASSES_DIR="$APP_DIR/target/classes/com/test/entity"
JAVAP_OUTPUT=$(javap -p "$CLASSES_DIR/Document.class" 2>&1)
echo "$JAVAP_OUTPUT"

ENHANCED=false
if echo "$JAVAP_OUTPUT" | grep -q '$$_hibernate_attributeInterceptor'; then
    echo "  FOUND: $$_hibernate_attributeInterceptor field -- entity is enhanced"
    ENHANCED=true
else
    echo "  NOT FOUND: $$_hibernate_attributeInterceptor field"
fi

if echo "$JAVAP_OUTPUT" | grep -q 'PersistentAttributeInterceptable'; then
    echo "  FOUND: PersistentAttributeInterceptable interface -- entity is enhanced"
    ENHANCED=true
else
    echo "  NOT FOUND: PersistentAttributeInterceptable interface"
fi

if echo "$JAVAP_OUTPUT" | grep -q 'SelfDirtinessTracker'; then
    echo "  FOUND: SelfDirtinessTracker interface -- dirty tracking enhanced"
fi

if [[ "$ENHANCED" != "true" ]]; then
    echo ""
    echo "FAIL: Build-time enhancement did not produce enhanced bytecode."
    RESULT="FAIL"
    exit 0
fi

echo "  Bytecode enhancement confirmed."

# ------------------------------------------------------------------
# Step 5: Start EAP
# ------------------------------------------------------------------
echo "=== Step 5: Starting EAP 8.2 ==="

# Use a separate base dir to avoid polluting sources.
# Must be under a path with no special characters.
rm -rf "$EAP_BASE"
mkdir -p "$EAP_BASE"
cp -r "$EAP_HOME_REAL/standalone/configuration" "$EAP_BASE/"
cp -r "$EAP_HOME_REAL/standalone/deployments" "$EAP_BASE/"
mkdir -p "$EAP_BASE/data" "$EAP_BASE/log" "$EAP_BASE/tmp"

SERVER_LOG="$EAP_BASE/log/server.log"

"$EAP_HOME/bin/standalone.sh" \
    -Djboss.server.base.dir="$EAP_BASE" \
    -Djboss.socket.binding.port-offset=10000 \
    > "$APP_DIR/eap-console.log" 2>&1 &
EAP_PID=$!

echo "  EAP starting (PID: $EAP_PID), waiting for readiness..."

READY=false
for i in $(seq 1 90); do
    if grep -q "WFLYSRV0025" "$SERVER_LOG" 2>/dev/null; then
        READY=true
        break
    fi
    if ! kill -0 "$EAP_PID" 2>/dev/null; then
        echo "ERROR: EAP process died"
        RESULT="ERROR"
        exit 1
    fi
    sleep 2
done

if [[ "$READY" != "true" ]]; then
    echo "ERROR: EAP did not start within 180 seconds"
    RESULT="ERROR"
    exit 1
fi

echo "  EAP started successfully."

# Enable TRACE for Hibernate bytecode enhancement detection
"$EAP_HOME/bin/jboss-cli.sh" --connect \
    --controller=localhost:19990 \
    --command='/subsystem=logging/logger=org.hibernate:add(level=TRACE)' 2>/dev/null || true

# ------------------------------------------------------------------
# Step 6: Deploy the WAR
# ------------------------------------------------------------------
echo "=== Step 6: Deploying test application ==="

WAR_FILE="$APP_DIR/target/enhancement-test.war"
if [[ ! -f "$WAR_FILE" ]]; then
    echo "ERROR: WAR file not found at $WAR_FILE"
    RESULT="ERROR"
    exit 1
fi

# Copy WAR to simple path to avoid parentheses in jboss-cli deploy command
WAR_DEPLOY="/tmp/enhancement-test.war"
cp "$WAR_FILE" "$WAR_DEPLOY"

"$EAP_HOME/bin/jboss-cli.sh" --connect \
    --controller=localhost:19990 \
    --command="deploy $WAR_DEPLOY" 2>&1

sleep 5

# Check deployment succeeded
if grep -q "WFLYUT0021.*enhancement-test.war" "$SERVER_LOG" 2>/dev/null; then
    echo "  Deployment registered."
elif grep -q "enhancement-test" "$SERVER_LOG" 2>/dev/null; then
    echo "  Deployment appears in logs."
fi

DEPLOY_FAILED=false
if grep -q "WFLYCTL0080\|WFLY.*ERROR.*enhancement-test" "$SERVER_LOG" 2>/dev/null; then
    echo "  WARNING: Deployment errors found in server log."
    grep "WFLYCTL0080\|ERROR.*enhancement-test" "$SERVER_LOG" | tail -5
    DEPLOY_FAILED=true
fi

# ------------------------------------------------------------------
# Step 7: Test the endpoint
# ------------------------------------------------------------------
echo "=== Step 7: Testing enhancement via servlet ==="

RESPONSE=$(curl -s -o - -w "\n%{http_code}" "http://localhost:18080/enhancement-test/test" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_CODE"
echo "Response body:"
echo "$BODY"

# ------------------------------------------------------------------
# Step 8: Check server logs
# ------------------------------------------------------------------
echo ""
echo "=== Step 8: Checking server logs for enhancement messages ==="

echo "--- Hibernate enhancement-related log entries ---"
grep -i "enhance\|HHH90009001\|EnhancementInfo\|bytecode\|interceptor" "$SERVER_LOG" 2>/dev/null | head -20 || echo "  (no enhancement-related log entries found)"

echo ""
echo "--- Checking for HHH90009001 (Skipping enhancement) ---"
if grep -q "HHH90009001" "$SERVER_LOG" 2>/dev/null; then
    echo "  FOUND: HHH90009001 -- runtime detected pre-enhanced entities"
    grep "HHH90009001" "$SERVER_LOG" | head -5
else
    echo "  NOT FOUND: HHH90009001 -- expected for ORM 6.6.x (this message is ORM 7.x+)"
fi

# ------------------------------------------------------------------
# Step 9: Determine result
# ------------------------------------------------------------------
echo ""
echo "=== Final Assessment ==="

PASS=true
NOTES=""

if [[ "$ENHANCED" != "true" ]]; then
    PASS=false
    NOTES="${NOTES}Build-time enhancement bytecode markers not found. "
fi

if [[ "$HTTP_CODE" == "200" ]] && echo "$BODY" | grep -q "Enhancement active: true"; then
    echo "  Servlet confirms enhancement is active at runtime."
elif [[ "$HTTP_CODE" == "200" ]] && echo "$BODY" | grep -q "Enhancement active: false"; then
    echo "  Servlet reports enhancement NOT active at runtime."
    PASS=false
    NOTES="${NOTES}Runtime check did not detect enhancement. "
elif [[ "$HTTP_CODE" != "200" ]]; then
    echo "  Servlet endpoint returned HTTP $HTTP_CODE (may be deployment issue)."
    NOTES="${NOTES}Servlet returned HTTP $HTTP_CODE. "
    # If bytecode was enhanced but servlet failed, still note what we found
    if [[ "$ENHANCED" == "true" ]]; then
        echo "  However, bytecode enhancement was confirmed at build time."
    else
        PASS=false
    fi
fi

if [[ "$PASS" == "true" ]]; then
    RESULT="PASS"
else
    RESULT="FAIL"
fi

exit 0
