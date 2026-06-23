#!/bin/bash
# Experiment 5: Version Mismatch Detection (Integration)
#
# Verifies:
# 1. Build-time enhance an app with Hibernate ORM 6.6.48.Final-redhat-00001 (productized)
# 2. Deploy to EAP 8.2 which ships 6.6.51.Final-redhat-00001 (productized)
# 3. Deployment should fail with a clear version mismatch error:
#    "Mismatch between Hibernate version used for bytecode enhancement (%s) and runtime (%s)"
#
# Differs from Experiment 3:
#   - Uses a productized (redhat) enhancement version, not community
#   - Wider version gap (6.6.48 vs 6.6.51, not 6.6.50 vs 6.6.51)
#   - Focuses on the WildFly JPA integration layer's mismatch detection

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCES="$BASE_DIR/sources"
EAP_HOME_REAL="$SOURCES/8.2.0.Alpha-CR39/jboss-eap-8.2"
MAVEN_REPO="$SOURCES/8.2.0.Alpha-CR39/jboss-eap-8.2.0.Alpha-maven-repository/maven-repository"
APP_DIR="$SCRIPT_DIR/05-test-app-version-mismatch-integration"
RESULT="ERROR"
EAP_PID=""

# Productized version for build-time enhancement (different from EAP's runtime)
ENHANCE_VERSION="6.6.48.Final-redhat-00001"
# Productized version EAP ships at runtime
RUNTIME_VERSION="6.6.51.Final-redhat-00001"

EAP_HOME="/tmp/eap-test-05-home"
EAP_BASE="/tmp/eap-test-05-base"

cleanup() {
    if [[ -n "$EAP_PID" ]]; then
        "$EAP_HOME/bin/jboss-cli.sh" --connect \
            --controller=localhost:19990 command=shutdown 2>/dev/null || true
        sleep 2
        kill "$EAP_PID" 2>/dev/null || true
        wait "$EAP_PID" 2>/dev/null || true
    fi
    rm -f "$EAP_HOME" /tmp/version-mismatch-integration-test.war
    rm -rf "$EAP_BASE"
    echo ""
    echo "========================================"
    echo "RESULT: $RESULT"
    echo "========================================"
}
trap cleanup EXIT

rm -f "$EAP_HOME"
ln -sfn "$EAP_HOME_REAL" "$EAP_HOME"

# ------------------------------------------------------------------
# Step 1: Verify mismatched plugin version is available locally
# ------------------------------------------------------------------
echo "=== Step 1: Verifying mismatched Hibernate version is available ==="

PLUGIN_JAR="$HOME/.m2/repository/org/hibernate/orm/tooling/hibernate-enhance-maven-plugin/$ENHANCE_VERSION/hibernate-enhance-maven-plugin-$ENHANCE_VERSION.jar"
CORE_JAR="$HOME/.m2/repository/org/hibernate/orm/hibernate-core/$ENHANCE_VERSION/hibernate-core-$ENHANCE_VERSION.jar"

if [[ ! -f "$PLUGIN_JAR" ]]; then
    echo "ERROR: hibernate-enhance-maven-plugin $ENHANCE_VERSION not found in local Maven cache"
    echo "  Available versions:"
    ls "$HOME/.m2/repository/org/hibernate/orm/tooling/hibernate-enhance-maven-plugin/" 2>/dev/null
    exit 1
fi
if [[ ! -f "$CORE_JAR" ]]; then
    echo "ERROR: hibernate-core $ENHANCE_VERSION not found in local Maven cache"
    echo "  Available versions:"
    ls "$HOME/.m2/repository/org/hibernate/orm/hibernate-core/" 2>/dev/null
    exit 1
fi

echo "  Enhancement plugin version: $ENHANCE_VERSION (productized, for build-time)"
echo "  EAP runtime version: $RUNTIME_VERSION (productized)"
echo "  Both available locally."

# ------------------------------------------------------------------
# Step 2: Install Maven artifacts into local Maven cache
# ------------------------------------------------------------------
echo "=== Step 2: Installing Maven artifacts into local Maven cache ==="

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

# Fix _remote.repositories tracking for the enhancement version.
# These were cached from a Red Hat repo that Maven can't reach without
# explicit repo config. Removing _remote.repositories and .lastUpdated
# makes Maven treat them as locally installed artifacts.
find "$HOME/.m2/repository" -path "*$ENHANCE_VERSION*/_remote.repositories" -exec rm -f {} \; 2>/dev/null
find "$HOME/.m2/repository" -path "*$ENHANCE_VERSION*/*.lastUpdated" -exec rm -f {} \; 2>/dev/null
echo "  Enhancement version cache entries fixed."

# Install EAP runtime version artifacts from sources
install_artifact \
    "$MAVEN_REPO/org/hibernate/orm/tooling/hibernate-enhance-maven-plugin/$RUNTIME_VERSION/hibernate-enhance-maven-plugin-$RUNTIME_VERSION.jar" \
    "$MAVEN_REPO/org/hibernate/orm/tooling/hibernate-enhance-maven-plugin/$RUNTIME_VERSION/hibernate-enhance-maven-plugin-$RUNTIME_VERSION.pom"

install_artifact \
    "$MAVEN_REPO/org/hibernate/orm/hibernate-core/$RUNTIME_VERSION/hibernate-core-$RUNTIME_VERSION.jar" \
    "$MAVEN_REPO/org/hibernate/orm/hibernate-core/$RUNTIME_VERSION/hibernate-core-$RUNTIME_VERSION.pom"

echo "  Runtime version artifacts installed."

# ------------------------------------------------------------------
# Step 3: Create test application
# ------------------------------------------------------------------
echo "=== Step 3: Creating test application (enhanced with $ENHANCE_VERSION) ==="

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/src/main/java/com/test/entity"
mkdir -p "$APP_DIR/src/main/java/com/test/servlet"
mkdir -p "$APP_DIR/src/main/resources/META-INF"
mkdir -p "$APP_DIR/src/main/webapp/WEB-INF"

cat > "$APP_DIR/pom.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.test</groupId>
    <artifactId>version-mismatch-integration-test</artifactId>
    <version>1.0</version>
    <packaging>war</packaging>

    <properties>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <!-- Deliberately use a DIFFERENT productized version than EAP's runtime ($RUNTIME_VERSION) -->
        <hibernate.version>$ENHANCE_VERSION</hibernate.version>
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
        <finalName>version-mismatch-integration-test</finalName>
        <plugins>
            <plugin>
                <groupId>org.hibernate.orm.tooling</groupId>
                <artifactId>hibernate-enhance-maven-plugin</artifactId>
                <version>\${hibernate.version}</version>
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

cat > "$APP_DIR/src/main/java/com/test/entity/Document.java" << 'JAVAEOF'
package com.test.entity;

import jakarta.persistence.Basic;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
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
JAVAEOF

cat > "$APP_DIR/src/main/java/com/test/servlet/TestServlet.java" << 'JAVAEOF'
package com.test.servlet;

import com.test.entity.Document;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
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
        out.println("Version mismatch integration test -- if you see this, deployment succeeded (unexpected).");

        try {
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

            out.println("Has $$_hibernate_attributeInterceptor: " + hasInterceptor);
            out.println("Implements PersistentAttributeInterceptable: " + implementsInterceptable);
            out.println("Enhancement active: " + (hasInterceptor && implementsInterceptable));
        } catch (Exception e) {
            out.println("ERROR: " + e.getMessage());
        }
        out.println("STATUS: OK");
    }
}
JAVAEOF

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
        </properties>
    </persistence-unit>
</persistence>
EOF

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
# Step 4: Build the application
# ------------------------------------------------------------------
echo "=== Step 4: Building test application (enhanced with $ENHANCE_VERSION) ==="

cd "$APP_DIR"
BUILD_LOG="$APP_DIR/build.log"
mvn clean package -o 2>&1 | tee "$BUILD_LOG"
MVN_EXIT=${PIPESTATUS[0]}

if [[ $MVN_EXIT -ne 0 ]]; then
    echo "  Offline build failed. Retrying with network for compile deps..."
    mvn clean package 2>&1 | tee "$BUILD_LOG"
    MVN_EXIT=${PIPESTATUS[0]}
fi

if [[ $MVN_EXIT -ne 0 ]]; then
    echo "ERROR: Maven build failed"
    RESULT="ERROR"
    exit 1
fi

echo "  Build succeeded."

# ------------------------------------------------------------------
# Step 5: Verify bytecode enhancement happened with mismatched version
# ------------------------------------------------------------------
echo "=== Step 5: Verifying bytecode enhancement ==="

CLASSES_DIR="$APP_DIR/target/classes/com/test/entity"
JAVAP_OUTPUT=$(javap -p "$CLASSES_DIR/Document.class" 2>&1)
echo "$JAVAP_OUTPUT"

ENHANCED=false
if echo "$JAVAP_OUTPUT" | grep -q '$$_hibernate_attributeInterceptor'; then
    echo "  FOUND: $$_hibernate_attributeInterceptor -- entity is enhanced"
    ENHANCED=true
else
    echo "  NOT FOUND: $$_hibernate_attributeInterceptor"
fi

if [[ "$ENHANCED" != "true" ]]; then
    echo "FAIL: Build-time enhancement did not produce enhanced bytecode with $ENHANCE_VERSION."
    RESULT="FAIL"
    exit 0
fi

echo "  Bytecode enhanced with $ENHANCE_VERSION confirmed."

echo ""
echo "--- Checking for version info in enhanced bytecode ---"
javap -v "$CLASSES_DIR/Document.class" 2>&1 | grep -i "EnhancementInfo\|version\|hibernate" | head -10 || echo "  (no version annotations visible in javap -v output)"
strings "$CLASSES_DIR/Document.class" 2>/dev/null | grep -i "$ENHANCE_VERSION\|EnhancementInfo\|6\.6\." | head -10 || echo "  (no version strings found in class file)"

# ------------------------------------------------------------------
# Step 6: Start EAP
# ------------------------------------------------------------------
echo ""
echo "=== Step 6: Starting EAP 8.2 (runtime version: $RUNTIME_VERSION) ==="

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

# Enable TRACE logging for Hibernate and the WildFly JPA integration layer
"$EAP_HOME/bin/jboss-cli.sh" --connect \
    --controller=localhost:19990 \
    --command='/subsystem=logging/logger=org.hibernate:add(level=TRACE)' 2>/dev/null || true

"$EAP_HOME/bin/jboss-cli.sh" --connect \
    --controller=localhost:19990 \
    --command='/subsystem=logging/logger=org.jboss.as.jpa:add(level=TRACE)' 2>/dev/null || true

"$EAP_HOME/bin/jboss-cli.sh" --connect \
    --controller=localhost:19990 \
    --command='/subsystem=logging/logger=org.jipijapa:add(level=TRACE)' 2>/dev/null || true

# ------------------------------------------------------------------
# Step 7: Deploy the WAR (expect failure)
# ------------------------------------------------------------------
echo "=== Step 7: Deploying version-mismatched application ==="
echo "  Enhancement version: $ENHANCE_VERSION (productized)"
echo "  Runtime version:     $RUNTIME_VERSION (productized)"
echo "  Expecting deployment failure with version mismatch error."
echo ""

WAR_FILE="$APP_DIR/target/version-mismatch-integration-test.war"
if [[ ! -f "$WAR_FILE" ]]; then
    echo "ERROR: WAR file not found at $WAR_FILE"
    RESULT="ERROR"
    exit 1
fi

WAR_DEPLOY="/tmp/version-mismatch-integration-test.war"
cp "$WAR_FILE" "$WAR_DEPLOY"

DEPLOY_OUTPUT=$("$EAP_HOME/bin/jboss-cli.sh" --connect \
    --controller=localhost:19990 \
    --command="deploy $WAR_DEPLOY" 2>&1) || true

echo "Deploy CLI output:"
echo "$DEPLOY_OUTPUT"

sleep 10

# ------------------------------------------------------------------
# Step 8: Analyze deployment result
# ------------------------------------------------------------------
echo ""
echo "=== Step 8: Analyzing deployment result ==="

echo "--- Server log entries related to version mismatch ---"
grep -i "mismatch\|version.*enhancement\|enhancement.*version\|HHH\|WFLYCTL0080\|WFLY.*ERROR\|failed.*deploy\|error.*deploy" "$SERVER_LOG" 2>/dev/null | tail -30 || echo "  (no relevant entries found)"

echo ""
echo "--- Checking for expected mismatch error message ---"
MISMATCH_FOUND=false
if grep -qi "Mismatch between Hibernate version" "$SERVER_LOG" 2>/dev/null; then
    echo "  FOUND: Version mismatch error in server log"
    grep -i "Mismatch between Hibernate version" "$SERVER_LOG" | head -5
    MISMATCH_FOUND=true
fi

if echo "$DEPLOY_OUTPUT" | grep -qi "Mismatch between Hibernate version"; then
    echo "  FOUND: Version mismatch error in CLI output"
    MISMATCH_FOUND=true
fi

DEPLOY_FAILED=false
if grep -q "WFLYCTL0080" "$SERVER_LOG" 2>/dev/null || echo "$DEPLOY_OUTPUT" | grep -qi "failed\|error\|WFLYCTL0080"; then
    echo "  Deployment FAILED (as expected for version mismatch)."
    DEPLOY_FAILED=true
else
    echo "  Deployment did NOT fail."
fi

echo ""
echo "--- Checking if app endpoint is reachable ---"
RESPONSE=$(curl -s -o - -w "\n%{http_code}" "http://localhost:18080/version-mismatch-integration-test/test" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')
echo "HTTP Status: $HTTP_CODE"
if [[ "$HTTP_CODE" == "200" ]]; then
    echo "Response: $BODY"
    echo "  App is reachable -- deployment succeeded despite version mismatch."
fi

# ------------------------------------------------------------------
# Step 9: Check WildFly JPA integration layer logs
# ------------------------------------------------------------------
echo ""
echo "=== Step 9: WildFly JPA integration layer analysis ==="

echo "--- JPA subsystem log entries ---"
grep -i "jpa\|jipijapa\|persistence.*unit\|EntityManagerFactory" "$SERVER_LOG" 2>/dev/null | grep -i "version-mismatch-integration\|enhance\|mismatch\|version" | tail -20 || echo "  (no relevant JPA integration entries)"

echo ""
echo "--- Hibernate ORM version loaded at runtime ---"
grep "HHH000412" "$SERVER_LOG" 2>/dev/null | head -3 || echo "  (HHH000412 version message not found)"

echo ""
echo "--- HHH90009001 (Skipping enhancement -- already annotated with @EnhancementInfo) ---"
if grep -q "HHH90009001" "$SERVER_LOG" 2>/dev/null; then
    echo "  FOUND: HHH90009001 -- runtime detected pre-enhanced entities"
    grep "HHH90009001" "$SERVER_LOG" | head -5
else
    echo "  NOT FOUND: HHH90009001 -- expected for ORM 6.6.x (this message is ORM 7.x+)"
fi

# ------------------------------------------------------------------
# Step 10: Full deployment-related log excerpt
# ------------------------------------------------------------------
echo ""
echo "=== Step 10: Full deployment-related log excerpt ==="
grep -i "version-mismatch-integration-test\|enhance\|mismatch\|WFLYCTL\|WFLY.*ERROR\|deploy.*fail\|fail.*deploy" "$SERVER_LOG" 2>/dev/null | tail -50 || echo "  (no deployment-related entries)"

# ------------------------------------------------------------------
# Step 11: Determine result
# ------------------------------------------------------------------
echo ""
echo "=== Final Assessment ==="

if [[ "$MISMATCH_FOUND" == "true" && "$DEPLOY_FAILED" == "true" ]]; then
    echo "  PASS: Deployment failed with expected version mismatch error."
    echo "  Enhancement version $ENHANCE_VERSION vs runtime $RUNTIME_VERSION detected correctly."
    RESULT="PASS"
elif [[ "$DEPLOY_FAILED" == "true" && "$MISMATCH_FOUND" != "true" ]]; then
    echo "  Deployment failed, but NOT with the expected version mismatch error message."
    echo "  Expected: 'Mismatch between Hibernate version used for bytecode enhancement (%s) and runtime (%s)'"
    RESULT="FAIL"
elif [[ "$DEPLOY_FAILED" != "true" ]]; then
    echo "  FAIL: Deployment succeeded despite version mismatch."
    echo "  Enhancement version: $ENHANCE_VERSION (productized)"
    echo "  Runtime version: $RUNTIME_VERSION (productized)"
    echo "  Expected deployment failure with version mismatch error."
    RESULT="FAIL"
fi

exit 0
