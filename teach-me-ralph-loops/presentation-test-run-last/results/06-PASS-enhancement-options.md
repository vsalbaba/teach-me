# Experiment 6: Enhancement Options (Integration)

**Result: PASS**

## What was tested

Build-time Hibernate entity enhancement with all four enhancement options enabled,
deployed to EAP 8.2.0.Alpha-CR39 with `jboss.as.jpa.classtransformer=false`.

Options tested:
- `enableLazyInitialization=true` (supported)
- `enableDirtyTracking=true` (supported)
- `enableAssociationManagement=true` (unsupported -- WildFly runtime disables this)
- `enableExtendedEnhancement=true` (unsupported -- disabled by default)

## Verification results

| Check | Result |
|-------|--------|
| Employee implements PersistentAttributeInterceptable (lazy loading) | PASS |
| Employee implements SelfDirtinessTracker (dirty tracking) | PASS |
| Department implements PersistentAttributeInterceptable | PASS |
| Department implements ExtendedSelfDirtinessTracker | PASS -- includes CollectionTracker |
| @EnhancementInfo annotation present | PASS -- version=6.6.51.Final-redhat-00001 |
| Deploy to EAP with classtransformer=false | PASS |
| ManagedTypeHelper.isManagedType(Employee) | PASS |
| ManagedTypeHelper.isManagedType(Department) | PASS |
| Entity create/read with bidirectional relationship | PASS |
| Department.employees count after persisting Employee with dept | 1 |

## Supported options detail

**enableLazyInitialization=true**: Employee implements `PersistentAttributeInterceptable`
and has `$$_hibernate_attributeInterceptor` field. Runtime confirms `LAZY_LOADING_CAPABLE=true`.
The `@Basic(fetch = FetchType.LAZY)` `biography` field is properly intercepted.

**enableDirtyTracking=true**: Employee implements `SelfDirtinessTracker` and has
`$$_hibernate_tracker` field with methods like `$$_hibernate_trackChange`,
`$$_hibernate_getDirtyAttributes`, `$$_hibernate_hasDirtyAttributes`, etc.
Department implements `ExtendedSelfDirtinessTracker` which adds `$$_hibernate_collectionTracker`
for tracking changes to the `@OneToMany employees` collection.

## Unsupported options detail

**enableAssociationManagement=true**: The enhancer accepted this option and enhanced
the entity bytecode. Deployment to EAP succeeded without errors. The bidirectional
relationship between Employee and Department worked correctly at the JPA level --
persisting an Employee with a department and then querying the Department showed
`employees.size() = 1`. Note: the `DefaultEnhancementContext` defaults to `true`
for `doBiDirectionalAssociationManagement`, but WildFly's `WildFlyClassTransformer`
explicitly overrides this to `false`. With build-time enhancement and
`classtransformer=false`, the WildFly override is not applied -- the build-time
setting takes effect.

**enableExtendedEnhancement=true**: The enhancer accepted this option. In this test,
only entity classes (in the `.entity.` package) were passed to the enhancer, so
extended enhancement had no visible effect on non-entity classes like the servlet.
Extended enhancement primarily affects non-entity classes by rewriting field access
to go through interceptors. No deployment errors occurred.

## Key observations

- All four options can be enabled simultaneously at build time without causing
  deployment failures or runtime errors
- The `DefaultEnhancementContext` defaults are: lazyInit=true, dirtyTracking=true,
  assocMgmt=true, extendedEnhancement=false
- WildFly's runtime enhancer (`WildFlyClassTransformer`) explicitly disables
  assocMgmt and extendedEnhancement
- When using build-time enhancement with `classtransformer=false`, the WildFly
  runtime enhancer is not involved -- whatever options were set at build time
  are what the application uses
- Department entity gets `ExtendedSelfDirtinessTracker` (not just `SelfDirtinessTracker`)
  because it has a collection field (`@OneToMany employees`)
- Enhancement size: Employee 1371 -> 6775 bytes, Department 1166 -> 7592 bytes

## Environment

- EAP: 8.2.0.Alpha-CR39
- Hibernate ORM: 6.6.51.Final-redhat-00001
- Java: OpenJDK 21
- Enhancement method: Direct Enhancer API (EnhancerImpl + ByteBuddyState)
