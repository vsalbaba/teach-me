# Experiment 1: Happy Path

**Result: PASS**

## What was tested

Build-time Hibernate entity enhancement using the Hibernate ORM 6.6.51.Final-redhat-00001
Enhancer API, deployed to EAP 8.2.0.Alpha-CR39 with `jboss.as.jpa.classtransformer=false`.

## Verification results

| Check | Result |
|-------|--------|
| Entity enhanced at build time | PASS -- 1077 -> 5930 bytes |
| Implements ManagedEntity | PASS |
| Implements PersistentAttributeInterceptable (lazy loading) | PASS |
| Implements SelfDirtinessTracker | PASS |
| @EnhancementInfo annotation present | PASS -- version=6.6.51.Final-redhat-00001 |
| Deploy to EAP with classtransformer=false | PASS |
| Entity create/read via servlet | PASS |
| HHH90009001 trace message | Not emitted (expected for ORM 6.6.x) |

## Key observations

- Enhancement adds `$$_hibernate_*` fields and methods to the entity class
  (entityEntryHolder, attributeInterceptor, tracker, etc.)
- The `@EnhancementInfo` annotation records the Hibernate ORM version used
  for enhancement, enabling version mismatch detection at deploy time
- With `classtransformer=false`, the runtime enhancer is disabled and the
  server uses the pre-enhanced bytecode directly
- The server log shows `jboss.as.jpa.classtransformer: false` was respected
- HHH90009001 ("Skipping enhancement -- already annotated with @EnhancementInfo")
  is not emitted in ORM 6.6.x as noted in the experiment description

## Environment

- EAP: 8.2.0.Alpha-CR39
- Hibernate ORM: 6.6.51.Final-redhat-00001
- Java: OpenJDK 21.0.4 (Temurin)
- Enhancement method: Direct Enhancer API (EnhancerImpl + ByteBuddyState)
