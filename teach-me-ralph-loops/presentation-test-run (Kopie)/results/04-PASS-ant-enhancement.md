# Experiment 4: Ant Enhancement

## Result: PASS

## What happened

Compiled entity classes were enhanced using Hibernate's `Enhancer` SPI called
from an Ant build, then deployed to EAP 8.2. Enhancement was confirmed both at
build time (via `javap`) and at runtime (via servlet introspection).

**Key observations:**

- ORM 6.6.x does not ship a dedicated Ant `EnhancementTask` class. The approach
  used a custom Java runner (`EnhanceRunner`) that calls
  `buildDefaultBytecodeProvider().getEnhancer(ctx)` directly, invoked from Ant's
  `<java>` task. This is functionally equivalent to what the Maven plugin does
  internally.

- The `discoverTypes()` phase ran before `enhance()`, matching the Maven plugin's
  two-pass approach.

- `javap` output confirmed all enhancement markers:
  - `$$_hibernate_attributeInterceptor` field present
  - `PersistentAttributeInterceptable` interface implemented
  - `SelfDirtinessTracker` interface implemented (dirty tracking)
  - `ManagedEntity` interface implemented

- The WAR deployed successfully to EAP 8.2 with no errors.

- Servlet response at `/ant-enhancement-test/test`:
  ```
  Enhancement active: true
  ```

- No HHH90009001 log message (expected -- this is ORM 6.6.x, not 7.x+).
