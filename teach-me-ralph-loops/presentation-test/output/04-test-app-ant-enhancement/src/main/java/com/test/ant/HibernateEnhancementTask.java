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
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;

/**
 * Custom Ant task for Hibernate bytecode enhancement using the Enhancer SPI.
 */
public class HibernateEnhancementTask extends Task {

    private File base;
    private boolean enableLazyInitialization = true;
    private boolean enableDirtyTracking = true;
    private boolean enableAssociationManagement = false;
    private boolean enableExtendedEnhancement = false;

    public void setBase(File base) {
        this.base = base;
    }

    public void setEnableLazyInitialization(boolean enable) {
        this.enableLazyInitialization = enable;
    }

    public void setEnableDirtyTracking(boolean enable) {
        this.enableDirtyTracking = enable;
    }

    public void setEnableAssociationManagement(boolean enable) {
        this.enableAssociationManagement = enable;
    }

    public void setEnableExtendedEnhancement(boolean enable) {
        this.enableExtendedEnhancement = enable;
    }

    @Override
    public void execute() throws BuildException {
        if (base == null || !base.isDirectory()) {
            throw new BuildException("'base' attribute must point to a valid directory");
        }

        log("Enhancing classes in: " + base.getAbsolutePath());

        Path classesDir = base.toPath();

        try {
            URLClassLoader cl = new URLClassLoader(
                new URL[]{ base.toURI().toURL() },
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
                    return enableExtendedEnhancement;
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

            final int[] count = {0};

            Files.walkFileTree(classesDir, new SimpleFileVisitor<Path>() {
                @Override
                public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
                    if (file.toString().endsWith(".class")) {
                        String relativePath = classesDir.relativize(file).toString();
                        String className = relativePath
                            .replace(File.separatorChar, '.')
                            .replace('/', '.')
                            .replaceAll("\\.class$", "");

                        // Only enhance entity classes (those in entity package)
                        if (className.contains(".entity.")) {
                            log("Enhancing: " + className);
                            byte[] original = Files.readAllBytes(file);
                            byte[] enhanced = enhancer.enhance(className, original);
                            if (enhanced != null) {
                                Files.write(file, enhanced);
                                log("  -> Enhanced (" + original.length + " -> " + enhanced.length + " bytes)");
                                count[0]++;
                            } else {
                                log("  -> No enhancement needed");
                            }
                        }
                    }
                    return FileVisitResult.CONTINUE;
                }
            });

            log("Enhancement complete. " + count[0] + " class(es) enhanced.");

        } catch (Exception e) {
            throw new BuildException("Enhancement failed: " + e.getMessage(), e);
        }
    }
}
