# SpringDoc Configuration

## Basic Configuration

```yaml
springdoc:
  api-docs:
    path: /api-docs
  swagger-ui:
    path: /swagger-ui.html
    operationsSorter: method
    tagsSorter: alpha
  packages-to-scan: com.example.web
  paths-to-match: /v1/**
```

## Access Endpoints

- **OpenAPI JSON**: `/v3/api-docs`
- **OpenAPI YAML**: `/v3/api-docs.yaml`
- **Swagger UI**: `/swagger-ui/index.html`

## OpenAPI Bean (Infrastructure Config)

```java
// infrastructure/config/OpenApiConfig.java
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
            .info(new Info()
                .title("订单服务 API")
                .version("v1.0")
                .description("订单管理服务接口文档"))
            .components(new Components()
                .addSecuritySchemes("bearer-jwt", new SecurityScheme()
                    .type(SecurityScheme.Type.HTTP)
                    .scheme("bearer")
                    .bearerFormat("JWT")));
    }
}
```

Apply on controllers: `@SecurityRequirement(name = "bearer-jwt")`

## API Groups

Group APIs by domain aggregate for Swagger UI navigation:

```java
@Bean
public GroupedOpenApi orderApi() {
    return GroupedOpenApi.builder()
        .group("订单")
        .packagesToScan("com.example.web")
        .pathsToMatch("/v1/orders/**")
        .build();
}
```

## Security Configuration (Spring Security 6.x)

Permit Swagger endpoints in `SecurityFilterChain` — otherwise Swagger UI returns 401/403:

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.authorizeHttpRequests(auth -> auth
                .requestMatchers("/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html").permitAll()
                .anyRequest().authenticated())
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()));
        return http.build();
    }
}
```

## Hide Internal Endpoints

```java
// Hide single endpoint
@Operation(hidden = true)
@GetMapping("/internal")
public Result<Void> internalEndpoint() { ... }

// Hide entire controller
@Hidden
@RestController
public class InternalController { ... }
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Startup fails with `NoSuchMethodError: HateoasProperties.getUseHalAsDefaultJsonMediaType` | Use SpringDoc >= 2.8.9; Spring Boot 3.5.0 renamed this method |
| Parameter names missing (`?` in Swagger) | Add `<parameters>true</parameters>` to `maven-compiler-plugin` |
| Swagger "Unable to render" | Register `ByteArrayHttpMessageConverter` |
| Endpoints not appearing | Check `packages-to-scan` and `paths-to-match` config |
| Swagger returns 401/403 | Permit `/v3/api-docs/**`, `/swagger-ui/**` in `SecurityFilterChain` |
| Performance slow on startup | Use specific package scanning + path matching; avoid scanning entire classpath |
| Using `javax.validation.*` annotations | SpringDoc requires `jakarta.validation.*` (Jakarta EE 10) for Spring Boot 3.5.x; `javax.*` annotations are not detected |
