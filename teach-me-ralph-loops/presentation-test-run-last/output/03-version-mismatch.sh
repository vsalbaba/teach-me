#!/bin/bash
# Experiment 3: Version Mismatch
#
# Verifies:
# 1. Build-time enhance an entity with a DIFFERENT Hibernate ORM version than EAP ships
# 2. Deploy to EAP with runtime class transformer enabled (classtransformer=true)
# 3. The runtime enhancer detects the version mismatch via @EnhancementInfo
# 4. Deployment fails with:
#    "Mismatch between Hibernate version used for bytecode enhancement (%s) and runtime (%s)"
#
# Approach: enhance with the real EAP Hibernate, then use ASM to rewrite the
# @EnhancementInfo(version=...) annotation to a fake version ("6.5.0.Final"),
# simulating a build-time / runtime version mismatch.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCES="$BASE_DIR/sources"
EAP_DIST="$SOURCES/8.2.0.Alpha-CR39/jboss-eap-8.2"
MODULES="$EAP_DIST/modules/system/layers/base"

APP_DIR="$SCRIPT_DIR/03-test-app-version-mismatch"
WORK_DIR=$(mktemp -d /tmp/exp03-version-mismatch.XXXXXX)

HIBERNATE_CORE="$MODULES/org/hibernate/main/hibernate-core-6.6.51.Final-redhat-00001.jar"
JPA_API="$MODULES/jakarta/persistence/api/main/jakarta.persistence-api-3.1.0.redhat-00002.jar"
BYTE_BUDDY="$MODULES/net/bytebuddy/main/byte-buddy-1.17.8.redhat-00001.jar"
JBOSS_LOGGING="$MODULES/org/jboss/logging/main/jboss-logging-3.6.3.Final-redhat-00001.jar"
TX_API="$MODULES/jakarta/transaction/api/main/jakarta.transaction-api-2.0.1.redhat-00004.jar"
SERVLET_API="$MODULES/jakarta/servlet/api/main/jakarta.servlet-api-6.0.0.redhat-00007.jar"
EJB_API="$MODULES/jakarta/ejb/api/main/jakarta.ejb-api-4.0.1.redhat-00001.jar"
INJECT_API="$MODULES/jakarta/inject/api/main/jakarta.inject-api-2.0.1.redhat-00007.jar"
ANNOTATION_API="$MODULES/jakarta/annotation/api/main/jakarta.annotation-api-2.1.1.redhat-00005.jar"

FAKE_VERSION="6.5.0.Final"
REAL_VERSION="6.6.51.Final-redhat-00001"

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

echo "=== Experiment 3: Version Mismatch ==="
echo "EAP Hibernate ORM version (runtime): $REAL_VERSION"
echo "Fake enhancement version (build-time): $FAKE_VERSION"

# ---- Step 1: Create the test application ----
echo ""
echo "--- Step 1: Creating test application ---"

mkdir -p "$APP_DIR/src/main/java/com/test/entity"
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

# persistence.xml with classtransformer=true so runtime enhancer activates
# and detects the version mismatch
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
            <!-- Enable runtime class transformer so it tries to re-enhance the entity -->
            <property name="jboss.as.jpa.classtransformer" value="true"/>
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

# ---- Step 2: Compile the application ----
echo ""
echo "--- Step 2: Compiling test application ---"

BUILD_DIR="$WORK_DIR/classes"
mkdir -p "$BUILD_DIR"

COMPILE_CP="$JPA_API:$SERVLET_API:$TX_API:$ANNOTATION_API:$INJECT_API:$EJB_API"

javac -d "$BUILD_DIR" \
    -classpath "$COMPILE_CP" \
    -source 17 -target 17 \
    "$APP_DIR/src/main/java/com/test/entity/Employee.java"

echo "Compilation successful"

# ---- Step 3: Enhance entity classes with real Hibernate version ----
echo ""
echo "--- Step 3: Running build-time bytecode enhancement ---"

ENHANCER_DIR="$WORK_DIR/enhancer"
mkdir -p "$ENHANCER_DIR"

cat > "$ENHANCER_DIR/RunEnhancer.java" << 'JAVA'
import org.hibernate.bytecode.enhance.spi.DefaultEnhancementContext;
import org.hibernate.bytecode.enhance.spi.EnhancementContext;
import org.hibernate.bytecode.enhance.spi.Enhancer;
import org.hibernate.bytecode.enhance.spi.UnloadedClass;
import org.hibernate.bytecode.enhance.spi.UnloadedField;
import org.hibernate.bytecode.enhance.internal.bytebuddy.EnhancerImpl;
import org.hibernate.bytecode.internal.bytebuddy.ByteBuddyState;

import java.io.*;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;

public class RunEnhancer {
    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            System.err.println("Usage: RunEnhancer <classes-dir>");
            System.exit(1);
        }

        Path classesDir = Paths.get(args[0]);

        EnhancementContext context = new DefaultEnhancementContext() {
            @Override
            public boolean doBiDirectionalAssociationManagement(UnloadedField field) {
                return false;
            }
            @Override
            public boolean doDirtyCheckingInline(UnloadedClass classDescriptor) {
                return true;
            }
            @Override
            public boolean doExtendedEnhancement(UnloadedClass classDescriptor) {
                return false;
            }
            @Override
            public boolean hasLazyLoadableAttributes(UnloadedClass classDescriptor) {
                return true;
            }
            @Override
            public ClassLoader getLoadingClassLoader() {
                return Thread.currentThread().getContextClassLoader();
            }
        };

        Enhancer enhancer = new EnhancerImpl(context, new ByteBuddyState());

        Files.walkFileTree(classesDir, new SimpleFileVisitor<Path>() {
            @Override
            public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
                if (file.toString().endsWith(".class")) {
                    String relativePath = classesDir.relativize(file).toString();
                    String className = relativePath
                        .replace(File.separatorChar, '.')
                        .replace('/', '.')
                        .replaceAll("\\.class$", "");

                    if (className.contains(".entity.")) {
                        System.out.println("Enhancing: " + className);
                        byte[] original = Files.readAllBytes(file);
                        byte[] enhanced = enhancer.enhance(className, original);
                        if (enhanced != null) {
                            Files.write(file, enhanced);
                            System.out.println("  -> Enhanced successfully (" +
                                original.length + " -> " + enhanced.length + " bytes)");
                        } else {
                            System.out.println("  -> No enhancement needed");
                        }
                    }
                }
                return FileVisitResult.CONTINUE;
            }
        });
    }
}
JAVA

ENHANCER_CP="$HIBERNATE_CORE:$JPA_API:$BYTE_BUDDY:$JBOSS_LOGGING:$TX_API:$INJECT_API:$BUILD_DIR"

javac -d "$ENHANCER_DIR" \
    -classpath "$ENHANCER_CP" \
    "$ENHANCER_DIR/RunEnhancer.java"

java -classpath "$ENHANCER_DIR:$ENHANCER_CP" RunEnhancer "$BUILD_DIR"

# ---- Step 4: Verify enhancement and @EnhancementInfo before modification ----
echo ""
echo "--- Step 4: Verifying @EnhancementInfo annotation before modification ---"

JAVAP_OUTPUT=$(javap -p -v -classpath "$BUILD_DIR" com.test.entity.Employee 2>&1)
if echo "$JAVAP_OUTPUT" | grep -q "EnhancementInfo"; then
    echo "VERIFIED: @EnhancementInfo annotation is present"
    echo "$JAVAP_OUTPUT" | grep -A2 "EnhancementInfo"
else
    echo "WARNING: @EnhancementInfo annotation NOT found -- version mismatch detection may not work"
fi

# ---- Step 5: Modify @EnhancementInfo version to simulate mismatch ----
echo ""
echo "--- Step 5: Rewriting @EnhancementInfo version to '$FAKE_VERSION' ---"

REWRITER_DIR="$WORK_DIR/rewriter"
mkdir -p "$REWRITER_DIR"

cat > "$REWRITER_DIR/RewriteVersion.java" << 'JAVA'
import net.bytebuddy.jar.asm.*;

import java.io.*;
import java.nio.file.*;

/**
 * Uses ASM (bundled in ByteBuddy) to rewrite the @EnhancementInfo annotation's
 * version() value to a different string, simulating a build-time / runtime
 * Hibernate version mismatch.
 */
public class RewriteVersion {
    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            System.err.println("Usage: RewriteVersion <class-file> <fake-version>");
            System.exit(1);
        }

        Path classFile = Paths.get(args[0]);
        String fakeVersion = args[1];

        byte[] original = Files.readAllBytes(classFile);
        ClassReader reader = new ClassReader(original);
        ClassWriter writer = new ClassWriter(0);

        ClassVisitor visitor = new ClassVisitor(Opcodes.ASM9, writer) {
            @Override
            public AnnotationVisitor visitAnnotation(String descriptor, boolean visible) {
                AnnotationVisitor av = super.visitAnnotation(descriptor, visible);
                if (descriptor.equals("Lorg/hibernate/bytecode/enhance/spi/EnhancementInfo;")) {
                    return new AnnotationVisitor(Opcodes.ASM9, av) {
                        @Override
                        public void visit(String name, Object value) {
                            if ("version".equals(name)) {
                                System.out.println("  Rewriting version: " + value + " -> " + fakeVersion);
                                super.visit(name, fakeVersion);
                            } else {
                                super.visit(name, value);
                            }
                        }
                    };
                }
                return av;
            }
        };

        reader.accept(visitor, 0);
        byte[] modified = writer.toByteArray();
        Files.write(classFile, modified);
        System.out.println("  Class file rewritten (" + original.length + " -> " + modified.length + " bytes)");
    }
}
JAVA

javac -d "$REWRITER_DIR" \
    -classpath "$BYTE_BUDDY" \
    "$REWRITER_DIR/RewriteVersion.java"

EMPLOYEE_CLASS="$BUILD_DIR/com/test/entity/Employee.class"
java -classpath "$REWRITER_DIR:$BYTE_BUDDY" RewriteVersion "$EMPLOYEE_CLASS" "$FAKE_VERSION"

# Verify the modification
echo ""
echo "Verifying modified @EnhancementInfo:"
JAVAP_AFTER=$(javap -p -v -classpath "$BUILD_DIR" com.test.entity.Employee 2>&1)
echo "$JAVAP_AFTER" | grep -A2 "EnhancementInfo" || echo "WARNING: Could not find EnhancementInfo in modified class"

# ---- Step 6: Package as WAR ----
echo ""
echo "--- Step 6: Packaging WAR ---"

WAR_DIR="$WORK_DIR/war"
mkdir -p "$WAR_DIR/WEB-INF/classes"

cp -r "$BUILD_DIR"/* "$WAR_DIR/WEB-INF/classes/"
cp "$APP_DIR/src/main/webapp/WEB-INF/web.xml" "$WAR_DIR/WEB-INF/"
mkdir -p "$WAR_DIR/WEB-INF/classes/META-INF"
cp "$APP_DIR/src/main/resources/META-INF/persistence.xml" "$WAR_DIR/WEB-INF/classes/META-INF/"

WAR_FILE="$WORK_DIR/test-mismatch.war"
(cd "$WAR_DIR" && jar cf "$WAR_FILE" .)
echo "WAR created: $WAR_FILE"

# ---- Step 7: Start EAP ----
echo ""
echo "--- Step 7: Starting EAP 8.2 ---"

EAP_HOME="$WORK_DIR/eap"
cp -r "$EAP_DIST" "$EAP_HOME"

# Enable TRACE logging for enhancement and JPA
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

# ---- Step 8: Deploy the application ----
echo ""
echo "--- Step 8: Deploying test application (expecting failure) ---"

cp "$WAR_FILE" "$EAP_HOME/standalone/deployments/"
touch "$EAP_HOME/standalone/deployments/test-mismatch.war.dodeploy"

echo "Waiting for deployment result..."
DEPLOYED=false
DEPLOY_FAILED=false
for i in $(seq 1 30); do
    if [ -f "$EAP_HOME/standalone/deployments/test-mismatch.war.deployed" ]; then
        DEPLOYED=true
        break
    fi
    if [ -f "$EAP_HOME/standalone/deployments/test-mismatch.war.failed" ]; then
        DEPLOY_FAILED=true
        break
    fi
    sleep 2
done

SERVER_LOG="$EAP_HOME/standalone/log/server.log"

# ---- Step 9: Check for version mismatch error ----
echo ""
echo "--- Step 9: Checking for version mismatch error ---"

MISMATCH_FOUND=false
MISMATCH_MSG=""
if grep -q "Mismatch between Hibernate version" "$SERVER_LOG"; then
    MISMATCH_FOUND=true
    MISMATCH_MSG=$(grep "Mismatch between Hibernate version" "$SERVER_LOG" | head -3)
    echo "FOUND version mismatch error in server log:"
    echo "$MISMATCH_MSG"
fi

VERSION_MISMATCH_EXCEPTION=false
if grep -q "VersionMismatchException" "$SERVER_LOG"; then
    VERSION_MISMATCH_EXCEPTION=true
    echo ""
    echo "FOUND VersionMismatchException in server log:"
    grep "VersionMismatchException" "$SERVER_LOG" | head -3
fi

echo ""
echo "Enhancement-related log messages:"
grep -i "enhance\|bytecode\|classtransformer\|EnhancementInfo" "$SERVER_LOG" | head -30 || echo "(none found)"

echo ""
echo "Deployment error messages:"
grep -i "ERROR\|WFLYCTL\|failed\|exception" "$SERVER_LOG" | tail -20 || echo "(none found)"

# ---- Step 10: Evaluate results ----
echo ""
echo "=========================================="
echo "=== RESULTS ==="
echo "=========================================="

RESULT="PASS"

if [ "$DEPLOY_FAILED" = "true" ]; then
    echo "OK: Deployment failed as expected"
else
    if [ "$DEPLOYED" = "true" ]; then
        echo "FAIL: Deployment succeeded -- expected it to fail with version mismatch"
        RESULT="FAIL"
    else
        echo "INFO: Deployment neither succeeded nor explicitly failed within timeout"
        # Check if EAP logged an error about the deployment
        if grep -q "WFLYSRV0022\|deploy.*failed\|deployment.*failed" "$SERVER_LOG"; then
            echo "OK: Server log shows deployment failure"
        else
            echo "FAIL: No deployment failure detected"
            RESULT="FAIL"
        fi
    fi
fi

if [ "$MISMATCH_FOUND" = "true" ]; then
    echo "OK: Version mismatch error message found in server log"
elif [ "$VERSION_MISMATCH_EXCEPTION" = "true" ]; then
    echo "OK: VersionMismatchException found in server log"
else
    echo "FAIL: No version mismatch error found in server log"
    RESULT="FAIL"
fi

echo ""
echo "Expected: deployment fails with 'Mismatch between Hibernate version used for"
echo "          bytecode enhancement ($FAKE_VERSION) and runtime ($REAL_VERSION)'"
echo "Actual deployment failed: $DEPLOY_FAILED"
echo "Actual deployed successfully: $DEPLOYED"
echo "Mismatch error in log: $MISMATCH_FOUND"
echo "VersionMismatchException in log: $VERSION_MISMATCH_EXCEPTION"

echo ""
echo "=========================================="
echo "$RESULT"
echo "=========================================="

exit 0
