# Experiment 5: Version Mismatch Detection (Integration)

## Result: FAIL

## Setup

- Build-time enhancement version: `6.6.48.Final-redhat-00001` (productized)
- EAP runtime version: `6.6.51.Final-redhat-00001` (productized)
- Enhancement confirmed in bytecode: `$$_hibernate_attributeInterceptor` field present via `javap`
- WildFly JPA integration layer TRACE logging enabled (`org.jboss.as.jpa`, `org.jipijapa`)

## What happened

1. App was built with `hibernate-enhance-maven-plugin:6.6.48.Final-redhat-00001` -- build succeeded, bytecode enhancement confirmed
2. App was deployed to EAP 8.2 (shipping Hibernate ORM `6.6.51.Final-redhat-00001`)
3. **Deployment succeeded** -- no version mismatch error was raised
4. Servlet endpoint returned HTTP 200, enhancement active at runtime (`$$_hibernate_attributeInterceptor: true`, `PersistentAttributeInterceptable: true`)
5. Server log shows: `HHH000412: Hibernate ORM core version 6.6.51.Final-redhat-00001` -- runtime loaded normally
6. No "Mismatch between Hibernate version" message appeared in server log or CLI output
7. HHH90009001 not found -- consistent with ORM 6.6.x behavior (expected in ORM 7.x+)
8. No version strings found in enhanced bytecode (`strings` on class file found no `6.6.48` markers)

## WildFly JPA Integration Layer Observations

- `org.jboss.as.jpa` loaded `HibernatePersistenceProviderAdaptor` from module `org.hibernate` version `6.6.51.Final-redhat-00001`
- JPA subsystem successfully created persistence unit `version-mismatch-integration-test.war#test-pu` in two phases
- `org.jipijapa` reported second level cache enabled without issue
- No version comparison or mismatch detection occurred in the WildFly integration layer

## What specifically did not match expected behavior

The experiment expected deployment to fail with the error message:
> "Mismatch between Hibernate version used for bytecode enhancement (%s) and runtime (%s)"

Instead, EAP accepted the version-mismatched enhanced bytecode without any warning or error, even with a productized-to-productized version gap (`6.6.48` vs `6.6.51`). Neither the Hibernate ORM runtime nor the WildFly JPA integration layer detected the mismatch. This confirms the finding from Experiment 3: version mismatch detection is not implemented in Hibernate ORM 6.6.x, regardless of whether community or productized versions are used. The `@EnhancementInfo` annotation and HHH90009001 message are expected in ORM 7.x+.
