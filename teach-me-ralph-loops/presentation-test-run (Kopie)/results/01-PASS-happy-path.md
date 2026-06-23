# Experiment 1: Happy Path

**Result: PASS**

## What was tested

Build an application with `hibernate-enhance-maven-plugin` (v6.6.51.Final-redhat-00001),
deploy to EAP 8.2 (8.2.0.Alpha-CR39), and confirm build-time bytecode enhancement is active.

## What happened

### Build-time enhancement (PASS)

The `hibernate-enhance-maven-plugin` ran during the Maven build:

```
[INFO] Starting Hibernate enhancement for classes on .../target/classes
```

`javap -p` on the compiled `Document.class` confirmed full enhancement:

- Implements `ManagedEntity`, `PersistentAttributeInterceptable`, `SelfDirtinessTracker`
- Has `$$_hibernate_attributeInterceptor` field (lazy initialization support)
- Has `$$_hibernate_tracker` field (dirty tracking support)
- Has generated `$$_hibernate_read_*` / `$$_hibernate_write_*` accessor methods for all fields

### Deployment to EAP 8.2 (PASS)

The enhanced WAR deployed successfully. Persistence unit `test-pu` started in two phases
(typical for JTA). H2 in-memory datasource (ExampleDS) was used. No deployment errors.

### Runtime enhancement check (PASS)

A servlet verified at runtime that the entity class:

- Has `$$_hibernate_attributeInterceptor` field: **true**
- Implements `PersistentAttributeInterceptable`: **true**
- Enhancement active: **true**

### HHH90009001 log message (NOT FOUND -- expected)

The trace message `HHH90009001` ("Skipping enhancement -- already annotated with @EnhancementInfo")
was not emitted. This is expected for ORM 6.6.x -- the `@EnhancementInfo` annotation and the
corresponding skip-detection log message are ORM 7.x+ features.

## Configuration used

- Hibernate ORM: 6.6.51.Final-redhat-00001
- Plugin: `hibernate-enhance-maven-plugin` with `enableLazyInitialization=true`, `enableDirtyTracking=true`
- Entity: `Document` with `@Basic(fetch = FetchType.LAZY)` on `content` field
- Datasource: ExampleDS (H2 in-memory)
- JPA config: `hibernate.hbm2ddl.auto=create-drop`, `hibernate.show_sql=true`
