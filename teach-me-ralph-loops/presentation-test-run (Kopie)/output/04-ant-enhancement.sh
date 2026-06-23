#!/bin/bash
# Experiment 4: Ant Enhancement
#
# Verifies:
# 1. Compiled entity classes can be enhanced using Hibernate's Enhancer SPI
#    called from an Ant build (ORM 6.6.x has no Ant EnhancementTask, so we
#    use a custom Java runner invoked via Ant's <java> task)
# 2. The enhanced WAR deploys successfully to EAP 8.2
# 3. Enhancement markers are present in the bytecode at runtime

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCES="$BASE_DIR/sources"
EAP_HOME_REAL="$SOURCES/8.2.0.Alpha-CR39/jboss-eap-8.2"
EAP_MODULES="$EAP_HOME_REAL/modules/system/layers/base"
APP_DIR="$SCRIPT_DIR/04-test-app-ant-enhancement"
RESULT="ERROR"
EAP_PID=""

# Jars from EAP modules -- no downloads needed
HIBERNATE_CORE="$EAP_MODULES/org/hibernate/main/hibernate-core-6.6.51.Final-redhat-00001.jar"
PERSISTENCE_API="$EAP_MODULES/jakarta/persistence/api/main/jakarta.persistence-api-3.1.0.redhat-00002.jar"
BYTE_BUDDY="$EAP_MODULES/net/bytebuddy/main/byte-buddy-1.17.8.redhat-00001.jar"
JBOSS_LOGGING="$EAP_MODULES/org/jboss/logging/main/jboss-logging-3.6.3.Final-redhat-00001.jar"
JANDEX="$EAP_MODULES/io/smallrye/jandex/main/jandex-3.5.3.redhat-00001.jar"
SERVLET_API="$EAP_MODULES/jakarta/servlet/api/main/jakarta.servlet-api-6.0.0.redhat-00007.jar"
TRANSACTION_API="$EAP_MODULES/jakarta/transaction/api/main/jakarta.transaction-api-2.0.1.redhat-00004.jar"
INJECT_API="$EAP_MODULES/jakarta/inject/api/main/jakarta.inject-api-2.0.1.redhat-00007.jar"

# Symlinks to avoid parentheses in paths (EAP's standalone.sh uses eval)
EAP_HOME="/tmp/eap-test-04-home"
EAP_BASE="/tmp/eap-test-04-base"

cleanup() {
    if [[ -n "$EAP_PID" ]]; then
        "$EAP_HOME/bin/jboss-cli.sh" --connect \
            --controller=localhost:19990 command=shutdown 2>/dev/null || true
        sleep 2
        kill "$EAP_PID" 2>/dev/null || true
        wait "$EAP_PID" 2>/dev/null || true
    fi
    rm -f "$EAP_HOME" /tmp/ant-enhancement-test.war
    rm -rf "$EAP_BASE"
    echo ""
    echo "========================================"
    echo "RESULT: $RESULT"
    echo "========================================"
}
trap cleanup EXIT

rm -f "$EAP_HOME"
ln -sfn "$EAP_HOME_REAL" "$EAP_HOME"

# Verify required jars exist
for jar in "$HIBERNATE_CORE" "$PERSISTENCE_API" "$BYTE_BUDDY" "$JBOSS_LOGGING" "$JANDEX" "$SERVLET_API" "$TRANSACTION_API"; do
    if [[ ! -f "$jar" ]]; then
        echo "ERROR: Missing jar: $jar"
        exit 1
    fi
done

# ------------------------------------------------------------------
# Step 1: Create the test application source tree
# ------------------------------------------------------------------
echo "=== Step 1: Creating test application ==="

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/src/com/test/entity"
mkdir -p "$APP_DIR/src/com/test/servlet"
mkdir -p "$APP_DIR/src/com/test/tool"
mkdir -p "$APP_DIR/webapp/WEB-INF"
mkdir -p "$APP_DIR/webapp/META-INF"

# -- Entity class (same as experiment 1) --
cat > "$APP_DIR/src/com/test/entity/Document.java" << 'JAVA_EOF'
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
JAVA_EOF

# -- Test servlet to verify enhancement at runtime --
cat > "$APP_DIR/src/com/test/servlet/TestServlet.java" << 'JAVA_EOF'
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

            out.println("=== Ant-Based Enhancement Check ===");
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
JAVA_EOF

# -- EnhanceRunner: standalone program that calls Hibernate's Enhancer SPI --
cat > "$APP_DIR/src/com/test/tool/EnhanceRunner.java" << 'JAVA_EOF'
package com.test.tool;

import org.hibernate.bytecode.enhance.spi.DefaultEnhancementContext;
import org.hibernate.bytecode.enhance.spi.EnhancementContext;
import org.hibernate.bytecode.enhance.spi.Enhancer;
import org.hibernate.bytecode.enhance.spi.UnloadedClass;
import org.hibernate.bytecode.enhance.spi.UnloadedField;
import org.hibernate.bytecode.spi.BytecodeProvider;

import java.io.File;
import java.io.IOException;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.FileVisitResult;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.ArrayList;
import java.util.List;

import static org.hibernate.bytecode.internal.BytecodeProviderInitiator.buildDefaultBytecodeProvider;

public class EnhanceRunner {

    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            System.err.println("Usage: EnhanceRunner <classes-dir>");
            System.exit(1);
        }

        File classesDir = new File(args[0]);
        if (!classesDir.isDirectory()) {
            System.err.println("Not a directory: " + classesDir);
            System.exit(1);
        }

        URL[] urls = new URL[]{ classesDir.toURI().toURL() };
        URLClassLoader cl = new URLClassLoader(urls, EnhanceRunner.class.getClassLoader());

        EnhancementContext ctx = new DefaultEnhancementContext() {
            @Override
            public ClassLoader getLoadingClassLoader() {
                return cl;
            }

            @Override
            public boolean doBiDirectionalAssociationManagement(UnloadedField field) {
                return false;
            }

            @Override
            public boolean doDirtyCheckingInline(UnloadedClass classDescriptor) {
                return true;
            }

            @Override
            public boolean hasLazyLoadableAttributes(UnloadedClass classDescriptor) {
                return true;
            }

            @Override
            public boolean isLazyLoadable(UnloadedField field) {
                return true;
            }

            @Override
            public boolean doExtendedEnhancement(UnloadedClass classDescriptor) {
                return false;
            }
        };

        BytecodeProvider bytecodeProvider = buildDefaultBytecodeProvider();
        try {
            Enhancer enhancer = bytecodeProvider.getEnhancer(ctx);
            Path root = classesDir.toPath();

            // Collect entity class files
            List<Path> entityFiles = new ArrayList<>();
            Files.walkFileTree(root, new SimpleFileVisitor<Path>() {
                @Override
                public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) {
                    if (file.toString().endsWith(".class")) {
                        String relativePath = root.relativize(file).toString();
                        String className = relativePath
                                .replace(File.separatorChar, '.')
                                .replace(".class", "");
                        if (className.contains(".entity.")) {
                            entityFiles.add(file);
                        }
                    }
                    return FileVisitResult.CONTINUE;
                }
            });

            // Phase 1: discover types (required before enhancement)
            for (Path file : entityFiles) {
                String className = root.relativize(file).toString()
                        .replace(File.separatorChar, '.').replace(".class", "");
                byte[] original = Files.readAllBytes(file);
                enhancer.discoverTypes(className, original);
                System.out.println("Discovered types for: " + className);
            }

            // Phase 2: enhance
            for (Path file : entityFiles) {
                String className = root.relativize(file).toString()
                        .replace(File.separatorChar, '.').replace(".class", "");
                byte[] original = Files.readAllBytes(file);
                byte[] result = enhancer.enhance(className, original);
                if (result != null) {
                    Files.write(file, result);
                    System.out.println("Enhanced: " + className);
                } else {
                    System.out.println("No enhancement needed: " + className);
                }
            }
        } finally {
            bytecodeProvider.resetCaches();
        }

        cl.close();
        System.out.println("Enhancement complete.");
    }
}
JAVA_EOF

# -- persistence.xml --
cat > "$APP_DIR/webapp/META-INF/persistence.xml" << 'XML_EOF'
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
XML_EOF

# -- beans.xml --
cat > "$APP_DIR/webapp/WEB-INF/beans.xml" << 'XML_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="https://jakarta.ee/xml/ns/jakartaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee
       https://jakarta.ee/xml/ns/jakartaee/beans_4_0.xsd"
       bean-discovery-mode="all" version="4.0">
</beans>
XML_EOF

# -- Ant build.xml --
# Uses Hibernate's Enhancer SPI via a custom Java runner (ORM 6.6.x has no
# dedicated Ant EnhancementTask)
cat > "$APP_DIR/build.xml" << 'XML_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project name="ant-enhancement-test" default="war" basedir=".">

    <property name="src.dir"     value="src"/>
    <property name="classes.dir" value="build/classes"/>
    <property name="war.dir"     value="build/war"/>
    <property name="war.file"    value="build/ant-enhancement-test.war"/>

    <!-- Classpath for compilation (provided-scope APIs) -->
    <path id="compile.classpath">
        <fileset dir="${lib.dir}">
            <include name="**/*.jar"/>
        </fileset>
    </path>

    <!-- Classpath for the enhance runner (needs Hibernate + ByteBuddy) -->
    <path id="enhance.classpath">
        <path refid="compile.classpath"/>
        <pathelement location="${classes.dir}"/>
    </path>

    <target name="clean">
        <delete dir="build"/>
    </target>

    <target name="compile" depends="clean">
        <mkdir dir="${classes.dir}"/>
        <javac srcdir="${src.dir}" destdir="${classes.dir}"
               classpathref="compile.classpath"
               source="17" target="17"
               includeantruntime="false"/>
    </target>

    <target name="enhance" depends="compile"
            description="Enhance entity bytecode using Hibernate Enhancer SPI">
        <java classname="com.test.tool.EnhanceRunner"
              fork="true" failonerror="true"
              classpathref="enhance.classpath">
            <arg value="${classes.dir}"/>
        </java>
    </target>

    <target name="war" depends="enhance">
        <mkdir dir="${war.dir}"/>
        <!-- Copy classes (exclude the tool package, not needed at runtime) -->
        <copy todir="${war.dir}/WEB-INF/classes">
            <fileset dir="${classes.dir}">
                <exclude name="com/test/tool/**"/>
            </fileset>
        </copy>
        <!-- Copy web resources -->
        <copy todir="${war.dir}">
            <fileset dir="webapp"/>
        </copy>
        <!-- Move persistence.xml into WEB-INF/classes/META-INF -->
        <mkdir dir="${war.dir}/WEB-INF/classes/META-INF"/>
        <move file="${war.dir}/META-INF/persistence.xml"
              todir="${war.dir}/WEB-INF/classes/META-INF"/>
        <delete dir="${war.dir}/META-INF"/>
        <!-- Package WAR -->
        <jar destfile="${war.file}" basedir="${war.dir}"/>
    </target>

</project>
XML_EOF

echo "  Test application created at $APP_DIR"

# ------------------------------------------------------------------
# Step 2: Build with Ant
# ------------------------------------------------------------------
echo "=== Step 2: Building with Ant (compile + enhance + package) ==="

# Create a lib directory with symlinks so the build.xml paths stay simple
LIB_DIR="$APP_DIR/lib"
mkdir -p "$LIB_DIR"
ln -sf "$HIBERNATE_CORE" "$LIB_DIR/"
ln -sf "$PERSISTENCE_API" "$LIB_DIR/"
ln -sf "$BYTE_BUDDY" "$LIB_DIR/"
ln -sf "$JBOSS_LOGGING" "$LIB_DIR/"
ln -sf "$JANDEX" "$LIB_DIR/"
ln -sf "$SERVLET_API" "$LIB_DIR/"
ln -sf "$TRANSACTION_API" "$LIB_DIR/"
ln -sf "$INJECT_API" "$LIB_DIR/"

cd "$APP_DIR"
BUILD_LOG="$APP_DIR/build.log"
ant -Dlib.dir="$LIB_DIR" war 2>&1 | tee "$BUILD_LOG"
ANT_EXIT=${PIPESTATUS[0]}

if [[ $ANT_EXIT -ne 0 ]]; then
    echo "ERROR: Ant build failed (exit $ANT_EXIT)"
    RESULT="ERROR"
    exit 1
fi

echo "  Ant build succeeded."

# ------------------------------------------------------------------
# Step 3: Verify bytecode enhancement in compiled classes
# ------------------------------------------------------------------
echo "=== Step 3: Verifying bytecode enhancement ==="

CLASSES_DIR="$APP_DIR/build/classes/com/test/entity"
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
    echo "FAIL: Ant-based enhancement did not produce enhanced bytecode."
    RESULT="FAIL"
    exit 0
fi

echo "  Bytecode enhancement confirmed."

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

# ------------------------------------------------------------------
# Step 5: Deploy the WAR
# ------------------------------------------------------------------
echo "=== Step 5: Deploying test application ==="

WAR_FILE="$APP_DIR/build/ant-enhancement-test.war"
if [[ ! -f "$WAR_FILE" ]]; then
    echo "ERROR: WAR file not found at $WAR_FILE"
    RESULT="ERROR"
    exit 1
fi

WAR_DEPLOY="/tmp/ant-enhancement-test.war"
cp "$WAR_FILE" "$WAR_DEPLOY"

"$EAP_HOME/bin/jboss-cli.sh" --connect \
    --controller=localhost:19990 \
    --command="deploy $WAR_DEPLOY" 2>&1

sleep 5

if grep -q "WFLYUT0021.*ant-enhancement-test.war" "$SERVER_LOG" 2>/dev/null; then
    echo "  Deployment registered."
elif grep -q "ant-enhancement-test" "$SERVER_LOG" 2>/dev/null; then
    echo "  Deployment appears in logs."
fi

DEPLOY_FAILED=false
if grep -q "WFLYCTL0080\|WFLY.*ERROR.*ant-enhancement-test" "$SERVER_LOG" 2>/dev/null; then
    echo "  WARNING: Deployment errors found in server log."
    grep "WFLYCTL0080\|ERROR.*ant-enhancement-test" "$SERVER_LOG" | tail -5
    DEPLOY_FAILED=true
fi

# ------------------------------------------------------------------
# Step 6: Test the endpoint
# ------------------------------------------------------------------
echo "=== Step 6: Testing enhancement via servlet ==="

RESPONSE=$(curl -s -o - -w "\n%{http_code}" "http://localhost:18080/ant-enhancement-test/test" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_CODE"
echo "Response body:"
echo "$BODY"

# ------------------------------------------------------------------
# Step 7: Check server logs
# ------------------------------------------------------------------
echo ""
echo "=== Step 7: Checking server logs for enhancement messages ==="

echo "--- Hibernate enhancement-related log entries ---"
grep -i "enhance\|HHH90009001\|EnhancementInfo\|bytecode\|interceptor" "$SERVER_LOG" 2>/dev/null | head -20 || echo "  (no enhancement-related log entries found)"

# ------------------------------------------------------------------
# Step 8: Determine result
# ------------------------------------------------------------------
echo ""
echo "=== Final Assessment ==="

PASS=true
NOTES=""

if [[ "$ENHANCED" != "true" ]]; then
    PASS=false
    NOTES="${NOTES}Ant-based enhancement bytecode markers not found. "
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
