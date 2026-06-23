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
