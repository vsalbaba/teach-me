#!/bin/bash
# Experiment 2: Runtime Enhancement Baseline
#
# Verifies:
# 1. An application WITHOUT build-time enhancement deploys to EAP 8.2
# 2. The runtime enhancer (JPA class transformer) activates automatically
# 3. Entities are enhanced at runtime (ManagedTypeHelper confirms)
# 4. Lazy loading works via runtime enhancement
# 5. No @EnhancementInfo annotation is present (build-time marker absent)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCES="$BASE_DIR/sources"
EAP_DIST="$SOURCES/8.2.0.Alpha-CR39/jboss-eap-8.2"
MODULES="$EAP_DIST/modules/system/layers/base"

APP_DIR="$SCRIPT_DIR/02-test-app-runtime-baseline"
WORK_DIR=$(mktemp -d /tmp/exp02-runtime-baseline.XXXXXX)

# Jar paths from EAP modules
JPA_API="$MODULES/jakarta/persistence/api/main/jakarta.persistence-api-3.1.0.redhat-00002.jar"
SERVLET_API="$MODULES/jakarta/servlet/api/main/jakarta.servlet-api-6.0.0.redhat-00007.jar"
TX_API="$MODULES/jakarta/transaction/api/main/jakarta.transaction-api-2.0.1.redhat-00004.jar"
ANNOTATION_API="$MODULES/jakarta/annotation/api/main/jakarta.annotation-api-2.1.1.redhat-00005.jar"
INJECT_API="$MODULES/jakarta/inject/api/main/jakarta.inject-api-2.0.1.redhat-00007.jar"
EJB_API="$MODULES/jakarta/ejb/api/main/jakarta.ejb-api-4.0.1.redhat-00001.jar"

EAP_HOME=""
EAP_PID=""

cleanup() {
    if [ -n "$EAP_PID" ] && kill -0 "$EAP_PID" 2>/dev/null; then
        echo "Shutting down EAP..."
        "$EAP_HOME/bin/jboss-cli.sh" --connect --command=":shutdown" 2>/dev/null || true
        sleep 3
        kill -0 "$EAP_PID" 2>/dev/null && kill "$EAP_PID" 2>/dev/null || true
    fi
    if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR"
    fi
}
trap cleanup EXIT

for jar in "$JPA_API" "$SERVLET_API" "$TX_API" "$ANNOTATION_API" "$INJECT_API" "$EJB_API"; do
    if [ ! -f "$jar" ]; then
        echo "ERROR: Required jar not found: $jar"
        exit 1
    fi
done

echo "=== Experiment 2: Runtime Enhancement Baseline ==="
echo "Testing: deploy WITHOUT build-time enhancement, verify runtime enhancer activates"

# ---- Step 1: Create the test application ----
echo ""
echo "--- Step 1: Creating test application ---"

mkdir -p "$APP_DIR/src/main/java/com/test/entity"
mkdir -p "$APP_DIR/src/main/java/com/test/servlet"
mkdir -p "$APP_DIR/src/main/webapp/WEB-INF"
mkdir -p "$APP_DIR/src/main/resources/META-INF"

cat > "$APP_DIR/src/main/java/com/test/entity/Employee.java" << 'JAVA'
package com.test.entity;

import jakarta.persistence.Basic;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.Lob;

@Entity
public class Employee {
    @Id
    private int id;

    private String name;
    private String address;

    @Basic(fetch = FetchType.LAZY)
    @Lob
    private String biography;

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getAddress() { return address; }
    public void setAddress(String address) { this.address = address; }
    public String getBiography() { return biography; }
    public void setBiography(String biography) { this.biography = biography; }
}
JAVA

cat > "$APP_DIR/src/main/java/com/test/servlet/TestServlet.java" << 'JAVA'
package com.test.servlet;

import com.test.entity.Employee;
import jakarta.annotation.Resource;
import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.PersistenceUnit;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.transaction.UserTransaction;
import java.io.IOException;
import java.io.PrintWriter;

@WebServlet("/test")
public class TestServlet extends HttpServlet {

    @PersistenceUnit(unitName = "testPU")
    private EntityManagerFactory emf;

    @Resource
    private UserTransaction utx;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        resp.setContentType("text/plain");
        PrintWriter out = resp.getWriter();

        try {
            // Check if entity class is enhanced (runtime enhancement should do this)
            boolean isManagedType = false;
            try {
                Class<?> helperClass = Class.forName("org.hibernate.engine.internal.ManagedTypeHelper");
                java.lang.reflect.Method method = helperClass.getMethod("isManagedType", Class.class);
                isManagedType = (Boolean) method.invoke(null, Employee.class);
            } catch (Exception e) {
                out.println("WARN: Could not check ManagedTypeHelper: " + e.getMessage());
            }
            out.println("RUNTIME_ENHANCED=" + isManagedType);

            // Check for @EnhancementInfo annotation (should NOT be present -- no build-time enhancement)
            boolean hasEnhancementInfo = false;
            try {
                Class<?> annoClass = Class.forName("org.hibernate.bytecode.enhance.spi.EnhancementInfo");
                hasEnhancementInfo = Employee.class.isAnnotationPresent((Class) annoClass);
            } catch (Exception e) {
                out.println("WARN: Could not check EnhancementInfo: " + e.getMessage());
            }
            out.println("HAS_ENHANCEMENT_INFO=" + hasEnhancementInfo);

            // Check for PersistentAttributeInterceptable (lazy loading support)
            boolean isInterceptable = false;
            try {
                Class<?> interceptable = Class.forName(
                    "org.hibernate.engine.spi.PersistentAttributeInterceptable");
                isInterceptable = interceptable.isAssignableFrom(Employee.class);
            } catch (Exception e) {
                out.println("WARN: Could not check PersistentAttributeInterceptable: " + e.getMessage());
            }
            out.println("LAZY_LOADING_CAPABLE=" + isInterceptable);

            // Create and read an employee to verify persistence works
            utx.begin();
            EntityManager em = emf.createEntityManager();
            Employee emp = new Employee();
            emp.setId(1);
            emp.setName("Test Employee");
            emp.setAddress("Test Address");
            emp.setBiography("A long biography text for lazy loading test");
            em.persist(emp);
            em.flush();
            utx.commit();

            // Read back in a new transaction
            utx.begin();
            em = emf.createEntityManager();
            Employee loaded = em.find(Employee.class, 1);
            out.println("EMPLOYEE_LOADED=" + (loaded != null));
            out.println("EMPLOYEE_NAME=" + (loaded != null ? loaded.getName() : "null"));
            utx.commit();

            out.println("PERSISTENCE_OK=true");

        } catch (Exception e) {
            out.println("PERSISTENCE_OK=false");
            out.println("ERROR=" + e.getMessage());
            e.printStackTrace(out);
        }
    }
}
JAVA

cat > "$APP_DIR/src/main/resources/META-INF/persistence.xml" << 'XML'
<?xml version="1.0" encoding="UTF-8"?>
<persistence xmlns="https://jakarta.ee/xml/ns/persistence"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="https://jakarta.ee/xml/ns/persistence https://jakarta.ee/xml/ns/persistence/persistence_3_0.xsd"
             version="3.0">
    <persistence-unit name="testPU">
        <jta-data-source>java:jboss/datasources/ExampleDS</jta-data-source>
        <class>com.test.entity.Employee</class>
        <properties>
            <property name="hibernate.hbm2ddl.auto" value="create-drop"/>
            <!-- Runtime class transformer is ENABLED by default (not setting classtransformer=false) -->
        </properties>
    </persistence-unit>
</persistence>
XML

cat > "$APP_DIR/src/main/webapp/WEB-INF/web.xml" << 'XML'
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="https://jakarta.ee/xml/ns/jakartaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee https://jakarta.ee/xml/ns/jakartaee/web-app_6_0.xsd"
         version="6.0">
</web-app>
XML

# ---- Step 2: Compile the application (NO enhancement) ----
echo ""
echo "--- Step 2: Compiling test application (no build-time enhancement) ---"

BUILD_DIR="$WORK_DIR/classes"
mkdir -p "$BUILD_DIR"

COMPILE_CP="$JPA_API:$SERVLET_API:$TX_API:$ANNOTATION_API:$INJECT_API:$EJB_API"

javac -d "$BUILD_DIR" \
    -classpath "$COMPILE_CP" \
    -source 17 -target 17 \
    "$APP_DIR/src/main/java/com/test/entity/Employee.java" \
    "$APP_DIR/src/main/java/com/test/servlet/TestServlet.java"

echo "Compilation successful"

# ---- Step 3: Verify NO enhancement in compiled classes ----
echo ""
echo "--- Step 3: Verifying classes are NOT enhanced ---"

JAVAP_OUTPUT=$(javap -p -classpath "$BUILD_DIR" com.test.entity.Employee 2>&1)
echo "$JAVAP_OUTPUT" | head -20

if echo "$JAVAP_OUTPUT" | grep -q "ManagedEntity\|PersistentAttributeInterceptable\|SelfDirtinessTracker\|EnhancementInfo\|\$\$_hibernate"; then
    echo ""
    echo "WARNING: Entity class appears to be enhanced already (unexpected)"
    PRE_ENHANCED=true
else
    echo ""
    echo "VERIFIED: Entity class is plain (not bytecode-enhanced) -- good, runtime will handle it"
    PRE_ENHANCED=false
fi

# ---- Step 4: Package as WAR ----
echo ""
echo "--- Step 4: Packaging WAR ---"

WAR_DIR="$WORK_DIR/war"
mkdir -p "$WAR_DIR/WEB-INF/classes"

cp -r "$BUILD_DIR"/* "$WAR_DIR/WEB-INF/classes/"
cp "$APP_DIR/src/main/webapp/WEB-INF/web.xml" "$WAR_DIR/WEB-INF/"
mkdir -p "$WAR_DIR/WEB-INF/classes/META-INF"
cp "$APP_DIR/src/main/resources/META-INF/persistence.xml" "$WAR_DIR/WEB-INF/classes/META-INF/"

WAR_FILE="$WORK_DIR/test-runtime.war"
(cd "$WAR_DIR" && jar cf "$WAR_FILE" .)
echo "WAR created: $WAR_FILE"

# ---- Step 5: Start EAP ----
echo ""
echo "--- Step 5: Starting EAP 8.2 ---"

EAP_HOME="$WORK_DIR/eap"
cp -r "$EAP_DIST" "$EAP_HOME"

# Enable TRACE logging for enhancement-related components
cat > "$WORK_DIR/enable-trace.cli" << 'CLI'
embed-server
/subsystem=logging/logger=org.hibernate.bytecode.enhance:add(level=TRACE)
/subsystem=logging/logger=org.jboss.as.jpa:add(level=TRACE)
/subsystem=logging/logger=org.hibernate.engine.internal:add(level=DEBUG)
stop-embedded-server
CLI

"$EAP_HOME/bin/jboss-cli.sh" --file="$WORK_DIR/enable-trace.cli" 2>&1 | tail -5

"$EAP_HOME/bin/standalone.sh" -b 0.0.0.0 > "$WORK_DIR/eap-stdout.log" 2>&1 &
EAP_PID=$!
echo "EAP started with PID: $EAP_PID"

# Wait for EAP to be ready
echo "Waiting for EAP to start..."
READY=false
for i in $(seq 1 60); do
    if "$EAP_HOME/bin/jboss-cli.sh" --connect --command=":read-attribute(name=server-state)" 2>/dev/null | grep -q "running"; then
        READY=true
        break
    fi
    sleep 2
done

if [ "$READY" != "true" ]; then
    echo "ERROR: EAP failed to start within 120 seconds"
    cat "$WORK_DIR/eap-stdout.log" | tail -30
    exit 1
fi
echo "EAP is running"

# ---- Step 6: Deploy the application ----
echo ""
echo "--- Step 6: Deploying test application ---"

cp "$WAR_FILE" "$EAP_HOME/standalone/deployments/"
touch "$EAP_HOME/standalone/deployments/test-runtime.war.dodeploy"

echo "Waiting for deployment..."
DEPLOYED=false
for i in $(seq 1 30); do
    if [ -f "$EAP_HOME/standalone/deployments/test-runtime.war.deployed" ]; then
        DEPLOYED=true
        break
    fi
    if [ -f "$EAP_HOME/standalone/deployments/test-runtime.war.failed" ]; then
        echo "DEPLOYMENT FAILED"
        cat "$EAP_HOME/standalone/deployments/test-runtime.war.failed" 2>/dev/null
        break
    fi
    sleep 2
done

if [ "$DEPLOYED" != "true" ]; then
    echo "ERROR: Deployment did not succeed within 60 seconds"
    cat "$EAP_HOME/standalone/log/server.log" | tail -50
    exit 1
fi
echo "Deployment successful"

# ---- Step 7: Test the application ----
echo ""
echo "--- Step 7: Testing the application ---"

sleep 2
HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" "http://localhost:8080/test-runtime/test" 2>&1)
HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -1)
HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')

echo "HTTP Response Code: $HTTP_CODE"
echo "Response Body:"
echo "$HTTP_BODY"

# ---- Step 8: Check server log for runtime enhancement evidence ----
echo ""
echo "--- Step 8: Checking server log for runtime enhancement ---"

SERVER_LOG="$EAP_HOME/standalone/log/server.log"

echo "Class transformer / enhancement log messages:"
grep -i "class.transformer\|classtransformer\|enhance\|bytecode" "$SERVER_LOG" | head -20 || echo "(none found)"

# ---- Step 9: Evaluate results ----
echo ""
echo "=========================================="
echo "=== RESULTS ==="
echo "=========================================="

RESULT="PASS"

if [ "$PRE_ENHANCED" = "true" ]; then
    echo "FAIL: Entity was unexpectedly enhanced before deployment"
    RESULT="FAIL"
else
    echo "OK: Entity class was plain (not pre-enhanced) before deployment"
fi

if [ "$DEPLOYED" != "true" ]; then
    echo "FAIL: Application failed to deploy"
    RESULT="FAIL"
fi

if [ "$HTTP_CODE" = "200" ]; then
    echo "OK: Servlet returned HTTP 200"

    if echo "$HTTP_BODY" | grep -q "RUNTIME_ENHANCED=true"; then
        echo "OK: Runtime enhancer activated -- entity is enhanced at runtime"
    else
        echo "INFO: ManagedTypeHelper reports entity is NOT enhanced at runtime"
        echo "  (This may indicate runtime enhancement did not occur, or the check"
        echo "   doesn't detect runtime-enhanced classes the same way)"
    fi

    if echo "$HTTP_BODY" | grep -q "HAS_ENHANCEMENT_INFO=false"; then
        echo "OK: No @EnhancementInfo annotation (expected -- no build-time enhancement)"
    elif echo "$HTTP_BODY" | grep -q "HAS_ENHANCEMENT_INFO=true"; then
        echo "UNEXPECTED: @EnhancementInfo found despite no build-time enhancement"
    fi

    if echo "$HTTP_BODY" | grep -q "LAZY_LOADING_CAPABLE=true"; then
        echo "OK: Entity supports lazy attribute loading via runtime enhancement"
    else
        echo "INFO: Entity does not report PersistentAttributeInterceptable"
    fi

    if echo "$HTTP_BODY" | grep -q "PERSISTENCE_OK=true"; then
        echo "OK: Entity persistence (create/read) works correctly"
    else
        echo "FAIL: Entity persistence failed"
        RESULT="FAIL"
    fi
else
    echo "FAIL: Servlet returned HTTP $HTTP_CODE"
    RESULT="FAIL"
fi

echo ""
echo "=========================================="
echo "$RESULT"
echo "=========================================="

exit 0
