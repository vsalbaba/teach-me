# Experiment 5: Version Mismatch Detection (Integration)

**Result: PASS**

## What was tested

Build-time enhanced an entity using a genuinely different Hibernate ORM version
(6.6.48.Final-redhat-00001) than EAP 8.2 ships at runtime (6.6.51.Final-redhat-00001).
Deployed with `jboss.as.jpa.classtransformer=true` so the runtime enhancer would
detect the version mismatch.

Unlike Experiment 3, which used ASM to rewrite the `@EnhancementInfo` annotation
to a fake version, this experiment used the actual Hibernate 6.6.48 Enhancer API
to create a genuine version mismatch -- the real-world scenario a developer would
hit when their build toolchain uses a different Hibernate version than the server.

## Verification results

| Check | Result |
|-------|--------|
| Entity enhanced with Hibernate 6.6.48 | PASS -- 1077 -> 5930 bytes |
| Deployment failed | PASS -- .war.failed marker created |
| VersionMismatchException thrown | PASS |
| Error message identifies both versions | PASS |

## Key error output

```
org.hibernate.bytecode.enhance.VersionMismatchException:
  Mismatch between Hibernate version used for bytecode enhancement
  (6.6.48.Final-redhat-00001) and runtime (6.6.51.Final-redhat-00001)
  for `com.test.entity.Employee`
```

The exception chain:
1. `EnhancerImpl.verifyVersions()` detects the version mismatch
2. `EnhancingClassTransformerImpl.transform()` wraps it as `TransformerException`
3. `DelegatingClassTransformer.transform()` propagates as `IllegalStateException`
4. Class fails to link -- `ClassFormatError: Failed to link com/test/entity/Employee`
5. Persistence unit fails to start -- `Unable to load class [com.test.entity.Employee]`
6. Deployment fails with `WFLYCTL0013: Operation ("deploy") failed`

## Key observations

- The version mismatch detection works with real (not simulated) version
  differences, confirming it would catch genuine developer mistakes
- The `@EnhancementInfo` annotation was NOT visible via `javap -v` for the 6.6.48
  enhanced class, yet the runtime still detected the mismatch -- indicating
  the version information is embedded in the bytecode in a way that the runtime
  enhancer can read even when not visible as a standard annotation to javap
- The error message clearly identifies both the build-time version
  (6.6.48.Final-redhat-00001) and runtime version (6.6.51.Final-redhat-00001),
  making the root cause immediately diagnosable
- Behavior is consistent with Experiment 3 (ASM-faked mismatch), confirming the
  detection mechanism is robust

## Environment

- EAP: 8.2.0.Alpha-CR39
- Hibernate ORM (runtime): 6.6.51.Final-redhat-00001
- Hibernate ORM (build-time enhancement): 6.6.48.Final-redhat-00001
- Java: OpenJDK 21.0.4 (Temurin)
- Enhancement method: Direct Enhancer API with actual different Hibernate version
