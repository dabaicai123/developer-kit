# GraalVM Reflection & Resource Configuration

Complete guide for GraalVM metadata files that enable reflection, resources, proxy, and serialization in native images.

## Configuration File Location

Place metadata files in:

```
src/main/resources/
  META-INF/native-image/
    <group.id>/
      <artifact.id>/
        reachability-metadata.json    # Unified format (recommended)
        reflect-config.json           # Legacy: reflection only
        resource-config.json          # Legacy: resources only
        proxy-config.json             # Legacy: dynamic proxies
        serialization-config.json     # Legacy: serialization
        jni-config.json               # Legacy: JNI access
        native-image.properties       # Build arguments
```

GraalVM automatically discovers files in the `META-INF/native-image/` directory.

## Unified Reachability Metadata

The unified `reachability-metadata.json` format (recommended for GraalVM 23+) combines all metadata:

```json
{
  "reflection": [
    {
      "type": "com.example.dto.UserDTO",
      "allDeclaredConstructors": true,
      "allDeclaredMethods": true,
      "allDeclaredFields": true
    },
    {
      "condition": {
        "typeReached": "com.example.service.OrderService"
      },
      "type": "com.example.dto.OrderDTO",
      "methods": [
        {"name": "<init>", "parameterTypes": []},
        {"name": "getId", "parameterTypes": []},
        {"name": "setId", "parameterTypes": ["java.lang.Long"]}
      ],
      "fields": [
        {"name": "id"},
        {"name": "status"}
      ]
    }
  ],
  "resources": [
    {"glob": "application.yml"},
    {"glob": "application-*.yml"},
    {"glob": "templates/**/*.html"},
    {"glob": "static/**"},
    {"glob": "META-INF/services/*"}
  ],
  "bundles": [
    {"name": "messages", "locales": ["en", "it", "de"]}
  ],
  "jni": [
    {
      "type": "com.example.NativeHelper",
      "methods": [
        {"name": "nativeMethod", "parameterTypes": ["int"]}
      ]
    }
  ]
}
```

## Reflection Configuration

### Legacy `reflect-config.json`

```json
[
  {
    "name": "com.example.dto.UserDTO",
    "allDeclaredConstructors": true,
    "allPublicConstructors": true,
    "allDeclaredMethods": true,
    "allPublicMethods": true,
    "allDeclaredFields": true,
    "allPublicFields": true
  },
  {
    "name": "com.example.dto.OrderDTO",
    "methods": [
      {"name": "<init>", "parameterTypes": []},
      {"name": "<init>", "parameterTypes": ["java.lang.Long", "java.lang.String"]},
      {"name": "getId", "parameterTypes": []},
      {"name": "setId", "parameterTypes": ["java.lang.Long"]}
    ],
    "fields": [
      {"name": "id", "allowWrite": true},
      {"name": "status", "allowWrite": true}
    ]
  },
  {
    "name": "com.example.entity.Product",
    "allDeclaredConstructors": true,
    "allDeclaredMethods": true,
    "allDeclaredFields": true,
    "unsafeAllocated": true
  }
]
```

### Common Reflection Flags

| Flag | Description |
|------|-------------|
| `allDeclaredConstructors` | Register all constructors (public and private) |
| `allPublicConstructors` | Register only public constructors |
| `allDeclaredMethods` | Register all methods (public and private) |
| `allPublicMethods` | Register only public methods |
| `allDeclaredFields` | Register all fields (public and private) |
| `allPublicFields` | Register only public fields |
| `unsafeAllocated` | Allow `Unsafe.allocateInstance()` |

## Resource Configuration

### Legacy `resource-config.json`

```json
{
  "resources": {
    "includes": [
      {"pattern": "application\\.yml"},
      {"pattern": "application-.*\\.yml"},
      {"pattern": "log4j2\\.xml"},
      {"pattern": "log4j2-spring\\.xml"},
      {"pattern": "META-INF/services/.*"},
      {"pattern": "templates/.*\\.html"},
      {"pattern": "static/.*"},
      {"pattern": "db/migration/.*\\.sql"}
    ],
    "excludes": [
      {"pattern": ".*\\.DS_Store"}
    ]
  },
  "bundles": [
    {"name": "messages", "locales": ["en", "it"]},
    {"name": "ValidationMessages"}
  ]
}
```

## Proxy Configuration

### Legacy `proxy-config.json`

Register interfaces for JDK dynamic proxy generation:

```json
[
  {
    "interfaces": [
      "com.example.service.UserService",
      "org.springframework.aop.SpringProxy",
      "org.springframework.aop.framework.Advised",
      "org.springframework.core.DecoratingProxy"
    ]
  },
  {
    "interfaces": [
      "com.example.repository.OrderRepository",
      "org.springframework.data.repository.Repository"
    ]
  }
]
```

## Serialization Configuration

### Legacy `serialization-config.json`

```json
{
  "types": [
    {"name": "com.example.dto.UserDTO"},
    {"name": "com.example.dto.OrderDTO"},
    {"name": "java.util.ArrayList"},
    {"name": "java.util.HashMap"}
  ],
  "lambdaCapturingTypes": [
    {"name": "com.example.service.UserService"}
  ]
}
```

## `native-image.properties`

Configure default build arguments:

```properties
Args = --no-fallback \
       -H:+ReportExceptionStackTraces \
       --enable-https \
       --initialize-at-build-time=org.slf4j
```
