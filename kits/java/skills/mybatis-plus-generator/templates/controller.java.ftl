package ${package.Controller};

import ${package.Entity}.${entity};
import ${package.Service}.${table.serviceName};
<#if swagger>
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
</#if>
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
<#if restControllerStyle>
import org.springframework.web.bind.annotation.RestController;
<#else>
import org.springframework.stereotype.Controller;
</#if>
<#if superControllerClassPackage??>
import ${superControllerClassPackage};
</#if>

/**
 * <p>${table.comment} controller</p>
 *
 * <p>Provides REST API interfaces related to ${table.comment}, including create, query, update, and delete operations.
 * This controller follows RESTful design conventions, using standard HTTP methods for resource operations.</p>
 *
 * <p>Primary functions:
 * <ul>
 *   <li>Create ${table.comment}</li>
 *   <li>Query ${table.comment} information by ID</li>
 *   <li>Update ${table.comment} information</li>
 *   <li>Delete ${table.comment}</li>
<#if customMethods??>
<#list customMethods as method>
 *   <li>${method.description}</li>
</#list>
</#if>
 * </ul>
 * </p>
 *
 * @author ${author}
 * @since ${date}
 */
<#if swagger>
@Tag(name = "${table.comment} Management", description = "${table.comment} management API")
</#if>
@RequiredArgsConstructor
<#if restControllerStyle>
@RestController
<#else>
@Controller
</#if>
@RequestMapping("<#if package.ModuleName??>/${package.ModuleName}</#if>/<#if controllerMappingHyphenStyle>${table.entityPath}<#else>${table.entityPath}</#if>"<#if superControllerClass??>, produces = "application/json;charset=UTF-8"</#if>)
<#if superControllerClass??>
public class ${table.controllerName} extends ${superControllerClass} {
<#else>
public class ${table.controllerName} {
</#if>

    private final ${table.serviceName} ${table.serviceName?substring(0,1)?lower_case}${table.serviceName?substring(1)};

    /**
     * <p>Create ${table.comment}</p>
     *
     * <p>Receive ${table.comment} creation request, validate data, create new ${table.comment} and return ${table.comment} information.</p>
     *
     * @param entity ${table.comment} entity object
     * @return ${table.comment} entity object
     */
<#if swagger>
    @Operation(summary = "Create ${table.comment}", description = "Create a new ${table.comment} record")
</#if>
    @PostMapping
    public ${entity} create(@RequestBody ${entity} entity) {
        return ${table.serviceName?substring(0,1)?lower_case}${table.serviceName?substring(1)}.save(entity) ? entity : null;
    }

    /**
     * <p>Query ${table.comment} by ID</p>
     *
     * <p>Query ${table.comment} detailed information by the provided ${table.comment} ID.</p>
     *
     * @param id ${table.comment} unique identifier
     * @return ${table.comment} entity object
     */
<#if swagger>
    @Operation(summary = "Query ${table.comment} by ID", description = "Query ${table.comment} detailed information by ID")
    @Parameter(name = "id", description = "${table.comment} ID", required = true)
</#if>
    @GetMapping("/{id}")
    public ${entity} getById(@PathVariable Long id) {
        return ${table.serviceName?substring(0,1)?lower_case}${table.serviceName?substring(1)}.getById(id);
    }

    /**
     * <p>Update ${table.comment}</p>
     *
     * <p>Update specified fields of ${table.comment} based on ID and update request.</p>
     *
     * @param id ${table.comment} unique identifier
     * @param entity ${table.comment} entity object
     * @return Updated ${table.comment} entity object
     */
<#if swagger>
    @Operation(summary = "Update ${table.comment}", description = "Update ${table.comment} information")
</#if>
    @PutMapping("/{id}")
    public ${entity} update(@PathVariable Long id, @RequestBody ${entity} entity) {
        entity.setId(id);
        return ${table.serviceName?substring(0,1)?lower_case}${table.serviceName?substring(1)}.updateById(entity) ? entity : null;
    }

    /**
     * <p>Delete ${table.comment}</p>
     *
     * <p>Delete the specified ${table.comment} by ID. The delete operation will cascade delete ${table.comment} related data.</p>
     *
     * @param id ${table.comment} unique identifier
     * @return Operation result
     */
<#if swagger>
    @Operation(summary = "Delete ${table.comment}", description = "Delete ${table.comment} by ID")
</#if>
    @DeleteMapping("/{id}")
    public boolean delete(@PathVariable Long id) {
        return ${table.serviceName?substring(0,1)?lower_case}${table.serviceName?substring(1)}.removeById(id);
    }
<#if customMethods??>

<#-- BEGIN Custom endpoints -->
<#list customMethods as method>
    /**
     * <p>${method.description}</p>
     *
     * <p>${method.detailDescription}</p>
     *
<#list method.parameters as param>
     * @param ${param.name} ${param.type} ${param.description}
</#list>
     * @return ${method.returnType} ${method.returnDescription}
     */
<#if swagger>
    @Operation(summary = "${method.description}", description = "${method.detailDescription}")
</#if>
    @GetMapping("/${method.mappingPath}")
    public ${method.returnType} ${method.name}(<#list method.parameters as param>@RequestParam ${param.type} ${param.name}<#if param_has_next>, </#if></#list>) {
        return ${table.serviceName?substring(0,1)?lower_case}${table.serviceName?substring(1)}.${method.name}(<#list method.parameters as param>${param.name}<#if param_has_next>, </#if></#list>);
    }
</#list>
<#-- END Custom endpoints -->
</#if>
}