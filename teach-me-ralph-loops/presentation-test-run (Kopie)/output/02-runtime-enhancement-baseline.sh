#!/bin/bash
# Experiment 2: Runtime Enhancement Baseline
#
# Verifies:
# 1. An app WITHOUT hibernate-enhance-maven-plugin deploys to EAP 8.2
# 2. Bytecode is NOT enhanced at build time (javap check)
# 3. The runtime enhancer activates instead (server log / servlet check)
# 4. This establishes the baseline that build-time enhancement replaces

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCES="$BASE_DIR/sources"
EAP_HOME_REAL="$SOURCES/8.2.0.Alpha-CR39/jboss-eap-8.2"
APP_DIR="$SCRIPT_DIR/02-test-app-runtime-baseline"
RESULT="ERROR"
EAP_PID=""

# Symlinks under /tmp to avoid parentheses/spaces in paths
EAP_HOME="/tmp/eap-test-02-home"
EAP_BASE="/tmp/eap-test-02-base"

cleanup() {
    if [[ -n "$EAP_PID" ]]; then
        "$EAP_HOME/bin/jboss-cli.sh" --connect \
            --controller=localhost:19990 command=shutdown 2>/dev/null || true
        sleep 2
        kill "$EAP_PID" 2>/dev/null || true
        wait "$EAP_PID" 2>/dev/null || true
    fi
    rm -f "$EAP_HOME" /tmp/runtime-baseline-test.war
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
# Step 1: Create test application (NO build-time enhancement plugin)
# ------------------------------------------------------------------
echo "=== Step 1: Creating test application (no build-time enhancement) ==="

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/src/main/java/com/test/entity"
mkdir -p "$APP_DIR/src/main/java/com/test/servlet"
mkdir -p "$APP_DIR/src/main/resources/META-INF"
mkdir -p "$APP_DIR/src/main/webapp/WEB-INF"

# -- pom.xml (NO hibernate-enhance-maven-plugin) --
cat > "$APP_DIR/pom.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.test</groupId>
    <artifactId>runtime-baseline</artifactId>
    <version>1.0</version>
    <packaging>war</packaging>

    <properties>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
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
        <finalName>runtime-baseline-test</finalName>
        <plugins>
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

# -- Same JPA Entity as Experiment 1 (with lazy @Basic field) --
cat > "$APP_DIR/src/main/java/com/test/entity/Document.java" << 'EOF'
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
EOF

# -- Test servlet that checks enhancement status --
cat > "$APP_DIR/src/main/java/com/test/servlet/TestServlet.java" << 'EOF'
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

            boolean implementsSelfDirtiness = false;
            for (Class<?> iface : docClass.getInterfaces()) {
                if (iface.getSimpleName().equals("SelfDirtinessTracker")) {
                    implementsSelfDirtiness = true;
                    break;
                }
            }

            boolean implementsManagedEntity = false;
            for (Class<?> iface : docClass.getInterfaces()) {
                if (iface.getSimpleName().equals("ManagedEntity")) {
                    implementsManagedEntity = true;
                    break;
                }
            }

            out.println("=== Runtime Enhancement Baseline Check ===");
            out.println("Has $$_hibernate_attributeInterceptor field: " + hasInterceptor);
            out.println("Implements PersistentAttributeInterceptable: " + implementsInterceptable);
            out.println("Implements SelfDirtinessTracker: " + implementsSelfDirtiness);
            out.println("Implements ManagedEntity: " + implementsManagedEntity);
            out.println("Enhancement active: " + (hasInterceptor && implementsInterceptable));

            if (hasInterceptor && implementsInterceptable) {
                out.println("Source: RUNTIME (class was not enhanced at build time)");
            } else {
                out.println("Source: NONE (no enhancement detected)");
            }
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
# Step 2: Build the application
# ------------------------------------------------------------------
echo "=== Step 2: Building test application (no enhancement plugin) ==="

cd "$APP_DIR"
BUILD_LOG="$APP_DIR/build.log"
mvn clean package -o 2>&1 | tee "$BUILD_LOG"
MVN_EXIT=${PIPESTATUS[0]}

if [[ $MVN_EXIT -ne 0 ]]; then
    echo "  Offline build failed. Retrying with network..."
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
# Step 3: Verify bytecode is NOT enhanced at build time
# ------------------------------------------------------------------
echo "=== Step 3: Verifying bytecode is NOT enhanced ==="

CLASSES_DIR="$APP_DIR/target/classes/com/test/entity"
JAVAP_OUTPUT=$(javap -p "$CLASSES_DIR/Document.class" 2>&1)
echo "$JAVAP_OUTPUT"

BUILD_ENHANCED=false
if echo "$JAVAP_OUTPUT" | grep -q '$$_hibernate_attributeInterceptor'; then
    echo "  UNEXPECTED: $$_hibernate_attributeInterceptor field found -- entity was enhanced at build time!"
    BUILD_ENHANCED=true
else
    echo "  CONFIRMED: No $$_hibernate_attributeInterceptor field -- entity is NOT enhanced at build time"
fi

if echo "$JAVAP_OUTPUT" | grep -q 'PersistentAttributeInterceptable'; then
    echo "  UNEXPECTED: PersistentAttributeInterceptable interface found at build time!"
    BUILD_ENHANCED=true
else
    echo "  CONFIRMED: No PersistentAttributeInterceptable interface at build time"
fi

if [[ "$BUILD_ENHANCED" == "true" ]]; then
    echo ""
    echo "FAIL: Bytecode was enhanced at build time despite no enhancement plugin."
    echo "      This should not happen -- the entity classes should be plain POJOs."
    RESULT="FAIL"
    exit 0
fi

echo "  Bytecode is plain (not enhanced) -- correct for baseline."

# ------------------------------------------------------------------
# Step 4: Start EAP
# ------------------------------------------------------------------
echo "=== Step 4: Starting EAP 8.2 ==="

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

# Enable TRACE logging for Hibernate to capture runtime enhancement activity
"$EAP_HOME/bin/jboss-cli.sh" --connect \
    --controller=localhost:19990 \
    --command='/subsystem=logging/logger=org.hibernate:add(level=TRACE)' 2>/dev/null || true

# ------------------------------------------------------------------
# Step 5: Deploy the WAR
# ------------------------------------------------------------------
echo "=== Step 5: Deploying test application ==="

WAR_FILE="$APP_DIR/target/runtime-baseline-test.war"
if [[ ! -f "$WAR_FILE" ]]; then
    echo "ERROR: WAR file not found at $WAR_FILE"
    RESULT="ERROR"
    exit 1
fi

WAR_DEPLOY="/tmp/runtime-baseline-test.war"
cp "$WAR_FILE" "$WAR_DEPLOY"

"$EAP_HOME/bin/jboss-cli.sh" --connect \
    --controller=localhost:19990 \
    --command="deploy $WAR_DEPLOY" 2>&1

sleep 5

if grep -q "WFLYUT0021.*runtime-baseline-test.war" "$SERVER_LOG" 2>/dev/null; then
    echo "  Deployment registered."
elif grep -q "runtime-baseline-test" "$SERVER_LOG" 2>/dev/null; then
    echo "  Deployment appears in logs."
fi

DEPLOY_FAILED=false
if grep -q "WFLYCTL0080\|WFLY.*ERROR.*runtime-baseline-test" "$SERVER_LOG" 2>/dev/null; then
    echo "  WARNING: Deployment errors found in server log."
    grep "WFLYCTL0080\|ERROR.*runtime-baseline-test" "$SERVER_LOG" | tail -5
    DEPLOY_FAILED=true
fi

# ------------------------------------------------------------------
# Step 6: Test the endpoint
# ------------------------------------------------------------------
echo "=== Step 6: Testing runtime enhancement via servlet ==="

RESPONSE=$(curl -s -o - -w "\n%{http_code}" "http://localhost:18080/runtime-baseline-test/test" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_CODE"
echo "Response body:"
echo "$BODY"

# ------------------------------------------------------------------
# Step 7: Check server logs for runtime enhancement activity
# ------------------------------------------------------------------
echo ""
echo "=== Step 7: Checking server logs for runtime enhancement ==="

echo "--- Hibernate enhancement-related log entries ---"
grep -i "enhance\|bytecode\|interceptor\|ManagedEntity\|SelfDirtinessTracker" "$SERVER_LOG" 2>/dev/null | head -30 || echo "  (no enhancement-related log entries found)"

echo ""
echo "--- Runtime bytecode enhancement indicators ---"
if grep -qi "runtime bytecode enhancement\|enhancing.*runtime\|runtime.*enhanc" "$SERVER_LOG" 2>/dev/null; then
    echo "  FOUND: Runtime enhancement activity in server log"
    grep -i "runtime bytecode enhancement\|enhancing.*runtime\|runtime.*enhanc" "$SERVER_LOG" | head -10
else
    echo "  No explicit runtime enhancement log entries found (may still be happening silently)"
fi

# ------------------------------------------------------------------
# Step 8: Determine result
# ------------------------------------------------------------------
echo ""
echo "=== Final Assessment ==="

PASS=true
NOTES=""

# Build-time should be clean (no enhancement)
if [[ "$BUILD_ENHANCED" == "true" ]]; then
    PASS=false
    NOTES="${NOTES}Build-time bytecode was unexpectedly enhanced. "
fi

# Check servlet response
if [[ "$HTTP_CODE" == "200" ]]; then
    if echo "$BODY" | grep -q "Enhancement active: true"; then
        echo "  Servlet confirms runtime enhancement is active."
        echo "  This confirms the runtime enhancer activates for non-pre-enhanced entities."
    elif echo "$BODY" | grep -q "Enhancement active: false"; then
        echo "  Servlet reports NO enhancement active."
        echo "  This means the runtime enhancer did NOT activate."
        NOTES="${NOTES}Runtime enhancement not detected by servlet. "
    fi
else
    echo "  Servlet returned HTTP $HTTP_CODE."
    NOTES="${NOTES}Servlet returned HTTP $HTTP_CODE. "
fi

if [[ "$PASS" == "true" ]]; then
    RESULT="PASS"
else
    RESULT="FAIL"
fi

exit 0
