# Experiment 4: Ant Enhancement

**Result: PASS**

## What was tested

Bytecode enhancement using a custom Ant task wrapping Hibernate's Enhancer SPI
(ORM 6.6.51.Final-redhat-00001), deployed to EAP 8.2 (Alpha-CR39) with
`jboss.as.jpa.classtransformer=false`.

Hibernate ORM 6.6.x does not ship a built-in Ant `EnhancementTask`. The test
created a custom Ant task (`com.test.ant.HibernateEnhancementTask`) that uses
the same `EnhancerImpl` and `DefaultEnhancementContext` SPI as the Maven plugin
approach in Experiment 1.

## Observations

- **Custom Ant task**: Compiled and ran successfully via `ant enhance`
- **Build-time enhancement**: Entity class (Employee) enhanced (1077 -> 5930 bytes) -- same result as Experiment 1
- **javap verification**: Enhanced class implements `ManagedEntity`, `PersistentAttributeInterceptable`, `SelfDirtinessTracker`
- **Deployment**: WAR deployed without errors
- **ManagedTypeHelper check**: `BUILD_TIME_ENHANCED=true` -- entity recognized as enhanced at runtime
- **@EnhancementInfo annotation**: Present, reporting version `6.6.51.Final-redhat-00001`
- **Lazy loading**: `LAZY_LOADING_CAPABLE=true` -- entity implements `PersistentAttributeInterceptable`
- **Persistence**: Entity create/read cycle completed successfully

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

## Ant build output

```
[hibernate-enhance] Enhancing classes in: /tmp/.../classes
[hibernate-enhance] Enhancing: com.test.entity.Employee
[hibernate-enhance]   -> Enhanced (1077 -> 5930 bytes)
[hibernate-enhance] Enhancement complete. 1 class(es) enhanced.

BUILD SUCCESSFUL
```
