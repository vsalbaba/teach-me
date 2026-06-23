# Experiment 4: Ant Enhancement

**Result: PASS**

## What was tested

Build-time Hibernate entity enhancement using a custom Ant task wrapping the
Hibernate ORM 6.6.51.Final-redhat-00001 Enhancer API (EnhancerImpl + ByteBuddyState),
deployed to EAP 8.2.0.Alpha-CR39 with `jboss.as.jpa.classtransformer=false`.

Hibernate ORM 6.6.x does not ship a built-in Ant `EnhancementTask`. The experiment
wrote a custom Ant task (`com.test.ant.HibernateEnhancementTask`) that extends
`org.apache.tools.ant.Task` and wraps the same Enhancer API used in Experiment 1.

## Verification results

| Check | Result |
|-------|--------|
| Custom Ant task compiles | PASS |
| Ant build runs enhancement | PASS -- 914 -> 5767 bytes |
| Implements ManagedEntity | PASS |
| Implements PersistentAttributeInterceptable (lazy loading) | PASS |
| Implements SelfDirtinessTracker | PASS |
| @EnhancementInfo annotation present | PASS -- version=6.6.51.Final-redhat-00001 |
| Deploy to EAP with classtransformer=false | PASS |
| Servlet returns HTTP 200 | PASS |
| BUILD_TIME_ENHANCED=true | PASS |
| Entity create/read via servlet | PASS |

## Key observations

- ORM 6.6.x has no built-in Ant task for enhancement; a custom task wrapping
  `EnhancerImpl` and `ByteBuddyState` is straightforward to write
- The Ant-driven enhancement produces identical results to the direct Java API
  approach in Experiment 1 (same interfaces implemented, same `$$_hibernate_*` fields)
- The `build.xml` used `<taskdef>` to register the custom task, then called it
  with `classesDir`, `enableLazyInitialization`, `enableDirtyTracking`, and
  `enableAssociationManagement` attributes
- Enhancement output is functionally equivalent regardless of build tool (Ant vs
  direct Java API) -- the underlying `EnhancerImpl` is the same

## Environment

- EAP: 8.2.0.Alpha-CR39
- Hibernate ORM: 6.6.51.Final-redhat-00001
- Java: OpenJDK 21.0.4 (Temurin)
- Ant: 1.10.15
- Enhancement method: Custom Ant task wrapping EnhancerImpl + ByteBuddyState
