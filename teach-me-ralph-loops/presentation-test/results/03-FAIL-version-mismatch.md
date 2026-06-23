# Experiment 3: Version Mismatch

**Result: FAIL**

## What was tested

Build-time enhanced an entity with Hibernate ORM, then patched the `@EnhancementInfo`
annotation's version string from `6.6.51.Final-redhat-00001` to `6.5.00.Final-redhat-99999`
(same-length binary replacement to keep bytecode valid). Deployed to EAP 8.2 (Alpha-CR39)
which runs Hibernate ORM 6.6.51.Final-redhat-00001 at runtime.

Tested with both `classtransformer=false` and `classtransformer=true` (default).

## Expected behavior

Deployment should fail with:
"Mismatch between Hibernate version used for bytecode enhancement (6.5.00.Final-redhat-99999) and runtime (6.6.51.Final-redhat-00001)"

## What actually happened

- **Enhancement**: Entity was successfully enhanced and @EnhancementInfo version patched to `6.5.00.Final-redhat-99999`
- **Deployment**: Succeeded without errors in both configurations
- **VersionMismatchException**: NOT thrown
- **Mismatch error message**: NOT found in server log
- **No enhancement-related log messages at all** during deployment

## Why it failed

The `VersionMismatchException` class exists in hibernate-core 6.6.51, but the runtime
check that compares `@EnhancementInfo.version()` against the running Hibernate version
is not active in ORM 6.6.x. The version mismatch detection does not trigger during
deployment or PU bootstrap.

The `@EnhancementInfo` annotation is stamped during build-time enhancement, but ORM
6.6.x does not validate it at runtime. This feature may be implemented in ORM 7.x+.

## Note

Only one version of hibernate-core is available in `sources/` (6.6.51.Final-redhat-00001),
so the version mismatch was simulated by binary-patching the `@EnhancementInfo` annotation's
version constant in the enhanced bytecode. The class file structure remains valid because
the replacement string is the same length (25 bytes).
