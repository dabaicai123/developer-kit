package ${package.Controller}

import ${package.Entity}.${entity}
import ${package.Service}.${table.serviceName}
<#if swagger>
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.Parameter
import io.swagger.v3.oas.annotations.tags.Tag
</#if>
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.web.bind.annotation.*
<#if superControllerClassPackage??>
import ${superControllerClassPackage}
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
<#if restControllerStyle>
@RestController
<#else>
@Controller
</#if>
@RequestMapping("<#if package.ModuleName??>/${package.ModuleName}</#if>/<#if controllerMappingHyphenStyle>${table.entityPath}<#else>${table.entityPath}</#if>"<#if superControllerClass??>, produces = ["application/json;charset=UTF-8"]</#if>)
<#if superControllerClass??>
class ${table.controllerName} : ${superControllerClass}() {
<#else>
class ${table.controllerName} {
</#if>

    private val ${table.serviceName?substring(0,1)?lower_case}${table.serviceName?substring(1)}: ${table.serviceName}

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
    fun create(@RequestBody entity: ${entity}): ${entity} {
        return ${table.serviceName?substring(0,1)?lower_case}${table.serviceName?substring(1)}.save(entity)
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
    fun getById(@PathVariable id: Long): ${entity} {
        return ${table.serviceName?substring(0,1)?lower_case}${table.serviceName?substring(1)}.getById(id)
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
    fun update(@PathVariable id: Long, @RequestBody entity: ${entity}): ${entity}? {
        entity.id = id
        return if (${table.serviceName?substring(0,1)?lower_case}${table.serviceName?substring(1)}.updateById(entity)) entity else null
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
    fun delete(@PathVariable id: Long): Boolean {
        return ${table.serviceName?substring(0,1)?lower_case}${table.serviceName?substring(1)}.removeById(id)
    }
<#if customMethods??>

## ----------  BEGIN Custom endpoints  ----------
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
    fun ${method.name}(<#list method.parameters as param>@RequestParam ${param.name}: ${param.type}<#if param_has_next>, </#if></#list>): ${method.returnType} {
        return ${table.serviceName?substring(0,1)?lower_case}${table.serviceName?substring(1)}.${method.name}(<#list method.parameters as param>${param.name}<#if param_has_next>, </#if></#list>)
    }
</#list>
## ----------  END Custom endpoints  ----------
</#if>
}