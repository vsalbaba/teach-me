# Experiment 3: Version Mismatch

**Result: PASS**

## What was tested

Build-time enhanced an entity with a fake Hibernate version ("6.5.0.Final") while
EAP 8.2 ships Hibernate ORM 6.6.51.Final-redhat-00001. Deployed with
`jboss.as.jpa.classtransformer=true` so the runtime enhancer would detect the mismatch.

Approach: enhanced with the real EAP Hibernate, then used ASM to rewrite the
`@EnhancementInfo(version=...)` annotation value from "6.6.51.Final-redhat-00001"
to "6.5.0.Final", simulating a build-time / runtime version mismatch.

## Verification results

| Check | Result |
|-------|--------|
| Entity enhanced at build time | PASS -- 1077 -> 5930 bytes |
| @EnhancementInfo version rewritten to 6.5.0.Final | PASS |
| Deployment failed | PASS -- .war.failed marker created |
| VersionMismatchException thrown | PASS |
| Error message matches expected format | PASS |

## Key error output

```
org.hibernate.bytecode.enhance.VersionMismatchException:
  Mismatch between Hibernate version used for bytecode enhancement (6.5.0.Final)
  and runtime (6.6.51.Final-redhat-00001) for `com.test.entity.Employee`
```

The exception chain:
1. `EnhancerImpl.verifyVersions()` detects the version mismatch
2. `EnhancingClassTransformerImpl.transform()` wraps it as `TransformerException`
3. `DelegatingClassTransformer.transform()` propagates as `IllegalStateException`
4. Class fails to link -- `ClassFormatError: Failed to link com/test/entity/Employee`
5. Persistence unit fails to start -- `Unable to load class [com.test.entity.Employee]`
6. Deployment fails with `WFLYCTL0013: Operation ("deploy") failed`

## Key observations

- The version mismatch is detected during **runtime class transformation**, not
  during deployment scanning -- the runtime enhancer (WildFlyClassTransformer)
  calls `EnhancerImpl.enhance()` which calls `verifyVersions()` and throws
  `VersionMismatchException` when `@EnhancementInfo.version()` differs from
  `Version.getVersionString()`
- With `classtransformer=false`, the mismatch would NOT be detected because
  the runtime enhancer never runs -- the app would deploy with the mismatched
  enhanced bytecode (whether it would work correctly is a separate question)
- The error message clearly identifies both the build-time version and runtime
  version, making the root cause immediately diagnosable

## Environment

- EAP: 8.2.0.Alpha-CR39
- Hibernate ORM (runtime): 6.6.51.Final-redhat-00001
- Fake enhancement version: 6.5.0.Final
- Java: OpenJDK 21.0.4 (Temurin)
- Enhancement method: Direct Enhancer API + ASM annotation rewrite
