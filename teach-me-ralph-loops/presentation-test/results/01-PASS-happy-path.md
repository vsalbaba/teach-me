# Experiment 1: Happy Path

**Result: PASS**

## What was tested

Build-time bytecode enhancement using the Hibernate Enhancer API (ORM 6.6.51.Final-redhat-00001),
deployed to EAP 8.2 (Alpha-CR39) with `jboss.as.jpa.classtransformer=false`.

## Observations

- **Build-time enhancement**: Entity class (Employee) was enhanced successfully (1077 -> 5930 bytes)
- **javap verification**: Enhanced class implements `ManagedEntity`, `PersistentAttributeInterceptable`, `SelfDirtinessTracker`
- **Deployment**: WAR deployed without errors
- **ManagedTypeHelper check**: `BUILD_TIME_ENHANCED=true` -- confirms entity is recognized as enhanced at runtime
- **@EnhancementInfo annotation**: Present, reporting version `6.6.51.Final-redhat-00001`
- **Lazy loading**: `LAZY_LOADING_CAPABLE=true` -- entity implements `PersistentAttributeInterceptable`
- **Persistence**: Entity create/read cycle completed successfully
- **HHH90009001**: Not found in server log (expected -- this message is not emitted in ORM 6.6.x)
- **classtransformer=false**: Log confirms JPA subsystem read this property, so runtime enhancement was disabled

## Key output

```
BUILD_TIME_ENHANCED=true
ENHANCEMENT_INFO_VERSION=6.6.51.Final-redhat-00001
HAS_ENHANCEMENT_INFO=true
LAZY_LOADING_CAPABLE=true
EMPLOYEE_LOADED=true
EMPLOYEE_NAME=Test Employee
PERSISTENCE_OK=true
```
