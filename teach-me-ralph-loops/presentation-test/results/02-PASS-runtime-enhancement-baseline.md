# Experiment 2: Runtime Enhancement Baseline

**Result: PASS**

## What was tested

Deployed a JPA application WITHOUT build-time bytecode enhancement to EAP 8.2
(Alpha-CR39). The persistence.xml does NOT set `jboss.as.jpa.classtransformer=false`,
leaving the default runtime behavior active. This establishes the baseline that
build-time enhancement is meant to replace.

## Observations

- **Pre-deployment check**: Entity class (Employee) is a plain POJO -- javap confirms no enhancement interfaces
- **Deployment**: WAR deployed without errors
- **ManagedTypeHelper check**: `RUNTIME_ENHANCED=false` -- entity is NOT recognized as enhanced at runtime
- **@EnhancementInfo annotation**: Not present (expected -- no build-time enhancement)
- **Lazy loading**: `LAZY_LOADING_CAPABLE=false` -- entity does not implement `PersistentAttributeInterceptable`
- **Persistence**: Entity create/read cycle completed successfully despite no enhancement
- **Server log**: No enhancement-related or class transformer messages found

## Key output

```
RUNTIME_ENHANCED=false
HAS_ENHANCEMENT_INFO=false
LAZY_LOADING_CAPABLE=false
EMPLOYEE_LOADED=true
EMPLOYEE_NAME=Test Employee
PERSISTENCE_OK=true
```

## Analysis

Without any form of bytecode enhancement, the entity functions as a plain POJO:
- Basic persistence (create/read) works correctly
- Lazy attribute loading (`@Basic(fetch=LAZY)`) is NOT actually lazy -- the `biography`
  field will be eagerly loaded since the entity lacks `PersistentAttributeInterceptable`
- No dirty tracking optimizations
- This confirms the baseline behavior that build-time enhancement (Experiment 1) improves upon
