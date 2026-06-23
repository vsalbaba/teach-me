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
