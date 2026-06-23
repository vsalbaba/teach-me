# Experiment 2: Runtime Enhancement Baseline

**Result: PASS**

## What was tested

Deploy the same entity model as Experiment 1 but WITHOUT the `hibernate-enhance-maven-plugin`.
Confirm the entity bytecode is plain at build time, then observe what happens at runtime
when EAP's Hibernate ORM encounters non-enhanced entities.

## What happened

### Build-time bytecode (CONFIRMED: not enhanced)

`javap -p` on the compiled `Document.class` shows a plain POJO -- no Hibernate-injected fields,
no enhancement interfaces:

```
public class com.test.entity.Document {
  private java.lang.Long id;
  private java.lang.String title;
  private java.lang.String content;
  // standard constructors and getters/setters only
}
```

No `$$_hibernate_attributeInterceptor`, no `PersistentAttributeInterceptable`, no
`SelfDirtinessTracker`, no `ManagedEntity`. This is the expected plain bytecode.

### Deployment to EAP 8.2 (SUCCESS)

The WAR deployed without errors. Persistence unit `test-pu` started normally using the
ExampleDS H2 datasource.

### Runtime enhancement (NOT ACTIVE)

The servlet confirmed no runtime enhancement occurred:

```
Has $$_hibernate_attributeInterceptor field: false
Implements PersistentAttributeInterceptable: false
Implements SelfDirtinessTracker: false
Implements ManagedEntity: false
Enhancement active: false
Source: NONE (no enhancement detected)
```

The server log shows:

```
DEBUG [org.hibernate.bytecode.internal.bytebuddy.BytecodeProviderImpl]
  HHH000513: Unable to create the ReflectionOptimizer for [com.test.entity.Document]: private accessor [content]
```

This indicates the bytecode provider attempted to create a ReflectionOptimizer but could not
fully optimize the class due to private field accessors.

### Baseline interpretation

In ORM 6.6.x, Hibernate does NOT automatically perform runtime bytecode enhancement on entity
classes. Without build-time enhancement via the Maven plugin, features like `@Basic(fetch =
FetchType.LAZY)` on basic fields will not work -- lazy initialization of basic attributes
requires the entity to implement `PersistentAttributeInterceptable`, which only happens through
explicit build-time enhancement.

This confirms the baseline: build-time enhancement (Experiment 1) is required for lazy basic
field loading to function. Runtime enhancement is not a fallback.

## Configuration used

- Hibernate ORM: 6.6.51.Final-redhat-00001 (provided by EAP 8.2)
- No `hibernate-enhance-maven-plugin` in pom.xml
- Entity: `Document` with `@Basic(fetch = FetchType.LAZY)` on `content` field
- Datasource: ExampleDS (H2 in-memory)
- JPA config: `hibernate.hbm2ddl.auto=create-drop`, `hibernate.show_sql=true`
