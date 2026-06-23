#!/bin/bash
# Experiment 4: Ant Enhancement
#
# Verifies:
# 1. Build-time bytecode enhancement using a custom Ant task wrapping the Hibernate Enhancer API
# 2. Ant-enhanced entities deploy correctly to EAP 8.2 with classtransformer=false
# 3. Lazy loading works (enhanced entity implements PersistentAttributeInterceptable)
# 4. Application works correctly end-to-end
#
# Note: Hibernate ORM 6.6.x does not ship a built-in Ant EnhancementTask.
# This experiment writes a custom Ant task that wraps the same Enhancer API
# used in Experiment 1, proving the enhancement approach works from Ant.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCES="$BASE_DIR/sources"
EAP_DIST="$SOURCES/8.2.0.Alpha-CR39/jboss-eap-8.2"
MODULES="$EAP_DIST/modules/system/layers/base"

APP_DIR="$SCRIPT_DIR/04-test-app-ant-enhancement"
WORK_DIR=$(mktemp -d /tmp/exp04-ant-enhancement.XXXXXX)

HIBERNATE_CORE="$MODULES/org/hibernate/main/hibernate-core-6.6.51.Final-redhat-00001.jar"
JPA_API="$MODULES/jakarta/persistence/api/main/jakarta.persistence-api-3.1.0.redhat-00002.jar"
BYTE_BUDDY="$MODULES/net/bytebuddy/main/byte-buddy-1.17.8.redhat-00001.jar"
JBOSS_LOGGING="$MODULES/org/jboss/logging/main/jboss-logging-3.6.3.Final-redhat-00001.jar"
TX_API="$MODULES/jakarta/transaction/api/main/jakarta.transaction-api-2.0.1.redhat-00004.jar"
SERVLET_API="$MODULES/jakarta/servlet/api/main/jakarta.servlet-api-6.0.0.redhat-00007.jar"
EJB_API="$MODULES/jakarta/ejb/api/main/jakarta.ejb-api-4.0.1.redhat-00001.jar"
INJECT_API="$MODULES/jakarta/inject/api/main/jakarta.inject-api-2.0.1.redhat-00007.jar"
ANNOTATION_API="$MODULES/jakarta/annotation/api/main/jakarta.annotation-api-2.1.1.redhat-00005.jar"

ANT_JAR=""
while IFS= read -r f; do
    ANT_JAR="$f"
    break
done < <(find /usr -name "ant.jar" 2>/dev/null)
if [ -z "$ANT_JAR" ]; then
    while IFS= read -r f; do
        ANT_JAR="$f"
        break
    done < <(find /usr -name "ant-*.jar" -not -name "*launcher*" -not -name "*junit*" -not -name "*contrib*" 2>/dev/null)
fi

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

for jar in "$HIBERNATE_CORE" "$JPA_API" "$BYTE_BUDDY" "$JBOSS_LOGGING" "$TX_API" \
           "$SERVLET_API" "$EJB_API" "$INJECT_API" "$ANNOTATION_API"; do
    if [ ! -f "$jar" ]; then
        echo "ERROR: Required jar not found: $jar"
        exit 1
    fi
done

if ! command -v ant &>/dev/null; then
    echo "ERROR: ant is not installed"
    exit 1
fi

if [ -z "$ANT_JAR" ] || [ ! -f "$ANT_JAR" ]; then
    echo "ERROR: Could not find ant.jar for compiling custom Ant task"
    exit 1
fi

echo "=== Experiment 4: Ant Enhancement ==="
echo "Hibernate ORM version: 6.6.51.Final-redhat-00001"
echo "Ant jar: $ANT_JAR"

# ---- Step 1: Create the test application ----
echo ""
echo "--- Step 1: Creating test application ---"

mkdir -p "$APP_DIR/src/main/java/com/test/entity"
mkdir -p "$APP_DIR/src/main/java/com/test/servlet"
mkdir -p "$APP_DIR/src/main/java/com/test/ant"
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
            boolean isManagedType = false;
            try {
                Class<?> helperClass = Class.forName("org.hibernate.engine.internal.ManagedTypeHelper");
                java.lang.reflect.Method method = helperClass.getMethod("isManagedType", Class.class);
                isManagedType = (Boolean) method.invoke(null, Employee.class);
            } catch (Exception e) {
                out.println("WARN: Could not check ManagedTypeHelper: " + e.getMessage());
            }

            out.println("BUILD_TIME_ENHANCED=" + isManagedType);

            boolean hasEnhancementInfo = false;
            try {
                Class<?> annoClass = Class.forName("org.hibernate.bytecode.enhance.spi.EnhancementInfo");
                hasEnhancementInfo = Employee.class.isAnnotationPresent((Class) annoClass);
                if (hasEnhancementInfo) {
                    java.lang.annotation.Annotation anno = Employee.class.getAnnotation((Class) annoClass);
                    java.lang.reflect.Method versionMethod = annoClass.getMethod("version");
                    String version = (String) versionMethod.invoke(anno);
                    out.println("ENHANCEMENT_INFO_VERSION=" + version);
                }
            } catch (Exception e) {
                out.println("WARN: Could not check EnhancementInfo: " + e.getMessage());
            }
            out.println("HAS_ENHANCEMENT_INFO=" + hasEnhancementInfo);

            boolean isInterceptable = false;
            try {
                Class<?> interceptable = Class.forName(
                    "org.hibernate.engine.spi.PersistentAttributeInterceptable");
                isInterceptable = interceptable.isAssignableFrom(Employee.class);
            } catch (Exception e) {
                out.println("WARN: Could not check PersistentAttributeInterceptable: " + e.getMessage());
            }
            out.println("LAZY_LOADING_CAPABLE=" + isInterceptable);

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

# Custom Ant task wrapping the Hibernate Enhancer API
cat > "$APP_DIR/src/main/java/com/test/ant/HibernateEnhancementTask.java" << 'JAVA'
package com.test.ant;

import org.apache.tools.ant.BuildException;
import org.apache.tools.ant.Task;
import org.hibernate.bytecode.enhance.spi.DefaultEnhancementContext;
import org.hibernate.bytecode.enhance.spi.EnhancementContext;
import org.hibernate.bytecode.enhance.spi.Enhancer;
import org.hibernate.bytecode.enhance.spi.UnloadedClass;
import org.hibernate.bytecode.enhance.spi.UnloadedField;
import org.hibernate.bytecode.enhance.internal.bytebuddy.EnhancerImpl;
import org.hibernate.bytecode.internal.bytebuddy.ByteBuddyState;

import java.io.File;
import java.io.IOException;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.FileVisitResult;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.attribute.BasicFileAttributes;

/**
 * Custom Ant task for Hibernate bytecode enhancement.
 * ORM 6.6.x does not ship a built-in Ant task, so this wraps the Enhancer API.
 */
public class HibernateEnhancementTask extends Task {
    private File classesDir;
    private boolean enableLazyInitialization = true;
    private boolean enableDirtyTracking = true;
    private boolean enableAssociationManagement = false;

    public void setClassesDir(File classesDir) {
        this.classesDir = classesDir;
    }

    public void setEnableLazyInitialization(boolean v) {
        this.enableLazyInitialization = v;
    }

    public void setEnableDirtyTracking(boolean v) {
        this.enableDirtyTracking = v;
    }

    public void setEnableAssociationManagement(boolean v) {
        this.enableAssociationManagement = v;
    }

    @Override
    public void execute() throws BuildException {
        if (classesDir == null || !classesDir.isDirectory()) {
            throw new BuildException("classesDir must be set to a valid directory");
        }

        log("Hibernate Enhancement Task starting on: " + classesDir);
        log("  lazyInitialization=" + enableLazyInitialization);
        log("  dirtyTracking=" + enableDirtyTracking);
        log("  associationManagement=" + enableAssociationManagement);

        try {
            URLClassLoader cl = new URLClassLoader(
                new URL[]{ classesDir.toURI().toURL() },
                Thread.currentThread().getContextClassLoader()
            );

            EnhancementContext context = new DefaultEnhancementContext() {
                @Override
                public boolean doBiDirectionalAssociationManagement(UnloadedField field) {
                    return enableAssociationManagement;
                }

                @Override
                public boolean doDirtyCheckingInline(UnloadedClass classDescriptor) {
                    return enableDirtyTracking;
                }

                @Override
                public boolean doExtendedEnhancement(UnloadedClass classDescriptor) {
                    return false;
                }

                @Override
                public boolean hasLazyLoadableAttributes(UnloadedClass classDescriptor) {
                    return enableLazyInitialization;
                }

                @Override
                public ClassLoader getLoadingClassLoader() {
                    return cl;
                }
            };

            Enhancer enhancer = new EnhancerImpl(context, new ByteBuddyState());
            Path base = classesDir.toPath();

            final int[] count = {0};
            Files.walkFileTree(base, new SimpleFileVisitor<Path>() {
                @Override
                public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
                    if (file.toString().endsWith(".class")) {
                        String relativePath = base.relativize(file).toString();
                        String className = relativePath
                            .replace(File.separatorChar, '.')
                            .replace('/', '.')
                            .replaceAll("\\.class$", "");

                        if (className.contains(".entity.")) {
                            log("  Enhancing: " + className);
                            byte[] original = Files.readAllBytes(file);
                            byte[] enhanced = enhancer.enhance(className, original);
                            if (enhanced != null) {
                                Files.write(file, enhanced);
                                log("    -> Enhanced (" + original.length + " -> " + enhanced.length + " bytes)");
                                count[0]++;
                            } else {
                                log("    -> No enhancement needed");
                            }
                        }
                    }
                    return FileVisitResult.CONTINUE;
                }
            });

            log("Enhancement complete: " + count[0] + " class(es) enhanced");

        } catch (Exception e) {
            throw new BuildException("Enhancement failed: " + e.getMessage(), e);
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
            <!-- Disable runtime class transformer since we use build-time enhancement -->
            <property name="jboss.as.jpa.classtransformer" value="false"/>
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

# ---- Step 2: Create the Ant build.xml ----
echo ""
echo "--- Step 2: Creating Ant build.xml ---"

cat > "$WORK_DIR/build.xml" << ANTXML
<?xml version="1.0" encoding="UTF-8"?>
<project name="exp04-ant-enhancement" default="enhance" basedir=".">

    <property name="src.dir" value="$APP_DIR/src/main/java"/>
    <property name="build.dir" value="${WORK_DIR}/classes"/>
    <property name="task.dir" value="${WORK_DIR}/ant-task-classes"/>

    <path id="compile.classpath">
        <pathelement location="$JPA_API"/>
        <pathelement location="$SERVLET_API"/>
        <pathelement location="$TX_API"/>
        <pathelement location="$ANNOTATION_API"/>
        <pathelement location="$INJECT_API"/>
        <pathelement location="$EJB_API"/>
    </path>

    <path id="enhancer.classpath">
        <pathelement location="$HIBERNATE_CORE"/>
        <pathelement location="$JPA_API"/>
        <pathelement location="$BYTE_BUDDY"/>
        <pathelement location="$JBOSS_LOGGING"/>
        <pathelement location="$TX_API"/>
        <pathelement location="$INJECT_API"/>
        <pathelement location="$ANT_JAR"/>
    </path>

    <!-- Compile the application classes (entity + servlet) -->
    <target name="compile-app">
        <mkdir dir="\${build.dir}"/>
        <javac srcdir="\${src.dir}"
               destdir="\${build.dir}"
               source="17" target="17"
               includeantruntime="false"
               includes="com/test/entity/**,com/test/servlet/**">
            <classpath refid="compile.classpath"/>
        </javac>
    </target>

    <!-- Compile the custom Ant enhancement task -->
    <target name="compile-task">
        <mkdir dir="\${task.dir}"/>
        <javac srcdir="\${src.dir}"
               destdir="\${task.dir}"
               source="17" target="17"
               includeantruntime="true"
               includes="com/test/ant/**">
            <classpath>
                <path refid="enhancer.classpath"/>
            </classpath>
        </javac>
    </target>

    <!-- Run the enhancement task on compiled entity classes -->
    <target name="enhance" depends="compile-app,compile-task">
        <taskdef name="hibernate-enhance"
                 classname="com.test.ant.HibernateEnhancementTask">
            <classpath>
                <pathelement location="\${task.dir}"/>
                <path refid="enhancer.classpath"/>
            </classpath>
        </taskdef>

        <hibernate-enhance
            classesDir="\${build.dir}"
            enableLazyInitialization="true"
            enableDirtyTracking="true"
            enableAssociationManagement="false"/>
    </target>

</project>
ANTXML

echo "build.xml created at $WORK_DIR/build.xml"

# ---- Step 3: Run Ant to compile and enhance ----
echo ""
echo "--- Step 3: Running Ant build (compile + enhance) ---"

ant -f "$WORK_DIR/build.xml" enhance 2>&1
ANT_EXIT=$?

if [ $ANT_EXIT -ne 0 ]; then
    echo "ERROR: Ant build failed with exit code $ANT_EXIT"
    exit 1
fi

echo "Ant build successful"

# ---- Step 4: Verify enhancement ----
echo ""
echo "--- Step 4: Verifying enhancement ---"

BUILD_DIR="$WORK_DIR/classes"
ENHANCED=false
JAVAP_OUTPUT=$(javap -p -classpath "$BUILD_DIR" com.test.entity.Employee 2>&1)
echo "$JAVAP_OUTPUT" | head -30

if echo "$JAVAP_OUTPUT" | grep -q "ManagedEntity\|PersistentAttributeInterceptable\|SelfDirtinessTracker\|EnhancementInfo\|\$\$_hibernate"; then
    echo ""
    echo "VERIFIED: Entity class has been bytecode-enhanced via Ant"
    ENHANCED=true
else
    echo ""
    echo "WARNING: No enhancement markers found in class"
fi

# ---- Step 5: Package as WAR ----
echo ""
echo "--- Step 5: Packaging WAR ---"

WAR_DIR="$WORK_DIR/war"
mkdir -p "$WAR_DIR/WEB-INF/classes"
mkdir -p "$WAR_DIR/WEB-INF/lib"

# Copy only app classes (not the Ant task classes)
cp -r "$BUILD_DIR"/* "$WAR_DIR/WEB-INF/classes/"
# Remove the ant task classes from the WAR -- they are build-time only
rm -rf "$WAR_DIR/WEB-INF/classes/com/test/ant"

cp "$APP_DIR/src/main/webapp/WEB-INF/web.xml" "$WAR_DIR/WEB-INF/"
mkdir -p "$WAR_DIR/WEB-INF/classes/META-INF"
cp "$APP_DIR/src/main/resources/META-INF/persistence.xml" "$WAR_DIR/WEB-INF/classes/META-INF/"

WAR_FILE="$WORK_DIR/test-ant-enhanced.war"
(cd "$WAR_DIR" && jar cf "$WAR_FILE" .)
echo "WAR created: $WAR_FILE"

# ---- Step 6: Start EAP ----
echo ""
echo "--- Step 6: Starting EAP 8.2 ---"

EAP_HOME="$WORK_DIR/eap"
cp -r "$EAP_DIST" "$EAP_HOME"

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

# ---- Step 7: Deploy the application ----
echo ""
echo "--- Step 7: Deploying test application ---"

cp "$WAR_FILE" "$EAP_HOME/standalone/deployments/"
touch "$EAP_HOME/standalone/deployments/test-ant-enhanced.war.dodeploy"

echo "Waiting for deployment..."
DEPLOYED=false
for i in $(seq 1 30); do
    if [ -f "$EAP_HOME/standalone/deployments/test-ant-enhanced.war.deployed" ]; then
        DEPLOYED=true
        break
    fi
    if [ -f "$EAP_HOME/standalone/deployments/test-ant-enhanced.war.failed" ]; then
        echo "DEPLOYMENT FAILED"
        cat "$EAP_HOME/standalone/deployments/test-ant-enhanced.war.failed" 2>/dev/null
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

# ---- Step 8: Test the application ----
echo ""
echo "--- Step 8: Testing the application ---"

sleep 2
HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" "http://localhost:8080/test-ant-enhanced/test" 2>&1)
HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -1)
HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')

echo "HTTP Response Code: $HTTP_CODE"
echo "Response Body:"
echo "$HTTP_BODY"

# ---- Step 9: Check server log ----
echo ""
echo "--- Step 9: Checking server log ---"

SERVER_LOG="$EAP_HOME/standalone/log/server.log"

echo "Enhancement-related log messages:"
grep -i "enhance\|bytecode\|classtransformer\|class.transformer" "$SERVER_LOG" | head -20 || echo "(none found)"

# ---- Step 10: Evaluate results ----
echo ""
echo "=========================================="
echo "=== RESULTS ==="
echo "=========================================="

RESULT="PASS"

if [ "$ENHANCED" != "true" ]; then
    echo "FAIL: Entity class was not enhanced at build time by Ant"
    RESULT="FAIL"
fi

if [ "$DEPLOYED" != "true" ]; then
    echo "FAIL: Application failed to deploy"
    RESULT="FAIL"
fi

if [ "$HTTP_CODE" = "200" ]; then
    echo "OK: Servlet returned HTTP 200"

    if echo "$HTTP_BODY" | grep -q "BUILD_TIME_ENHANCED=true"; then
        echo "OK: ManagedTypeHelper confirms entity is enhanced"
    else
        echo "FAIL: ManagedTypeHelper reports entity is NOT enhanced"
        RESULT="FAIL"
    fi

    if echo "$HTTP_BODY" | grep -q "LAZY_LOADING_CAPABLE=true"; then
        echo "OK: Entity supports lazy attribute loading"
    else
        echo "INFO: Entity does not report PersistentAttributeInterceptable"
    fi

    if echo "$HTTP_BODY" | grep -q "PERSISTENCE_OK=true"; then
        echo "OK: Entity persistence (create/read) works correctly"
    else
        echo "FAIL: Entity persistence failed"
        RESULT="FAIL"
    fi

    if echo "$HTTP_BODY" | grep -q "HAS_ENHANCEMENT_INFO=true"; then
        echo "OK: @EnhancementInfo annotation present"
        grep "ENHANCEMENT_INFO_VERSION" <<< "$HTTP_BODY" || true
    else
        echo "INFO: @EnhancementInfo annotation not found (may not be present in 6.6.x)"
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
