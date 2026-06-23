# Experiment 3: Version Mismatch

## Result: FAIL

## Setup

- Build-time enhancement version: `6.6.50.Final` (community)
- EAP runtime version: `6.6.51.Final-redhat-00001`
- Enhancement confirmed in bytecode: `@EnhancementInfo` annotation with version `6.6.50.Final` found via `strings` on compiled class
- `javap` confirmed `$$_hibernate_attributeInterceptor` field and `PersistentAttributeInterceptable` interface present

## What happened

1. App was built with `hibernate-enhance-maven-plugin:6.6.50.Final` -- build succeeded, bytecode enhancement confirmed
2. App was deployed to EAP 8.2 (shipping Hibernate ORM `6.6.51.Final-redhat-00001`)
3. **Deployment succeeded** -- no version mismatch error was raised
4. Servlet endpoint returned HTTP 200 and was fully functional
5. Server log shows: `HHH000412: Hibernate ORM core version 6.6.51.Final-redhat-00001` -- runtime loaded normally
6. No "Mismatch between Hibernate version" message appeared in server log or CLI output

## What specifically did not match expected behavior

The experiment expected deployment to fail with the error message:
> "Mismatch between Hibernate version used for bytecode enhancement (%s) and runtime (%s)"

Instead, EAP accepted the version-mismatched enhanced bytecode without any warning or error. The version mismatch detection feature does not appear to be implemented in Hibernate ORM 6.6.x. This is consistent with the note on Experiment 1 that `HHH90009001` is "not emitted in ORM 6.6.x -- expected in ORM 7.x+," suggesting these build-time enhancement detection features are planned for a future ORM version.
