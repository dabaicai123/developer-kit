package ${package.Repository}

import ${package.Entity}.${entity}
import java.util.List
import java.util.Optional

/**
 * <p>${table.comment} repository interface</p>
 *
 * <p>Defines the repository interface for the ${table.comment} aggregate, following Domain-Driven Design (DDD) principles.
 * The repository interface is located in the domain layer, defining the persistence contract for the ${table.comment} aggregate, without depending on specific technical implementations.</p>
 *
 * <p>Primary responsibilities:
 * <ul>
 *   <li>Save ${table.comment} aggregate</li>
 *   <li>Find ${table.comment} aggregate by ID</li>
 *   <li>Delete ${table.comment} aggregate</li>
 *   <li>Query ${table.comment} aggregate list</li>
 *   <li>Batch save ${table.comment} aggregates</li>
 *   <li>Batch delete ${table.comment} aggregates</li>
 *   <li>Check if ${table.comment} aggregate exists</li>
 *   <li>Count ${table.comment} aggregates</li>
<#if customMethods??>
<#list customMethods as method>
 *   <li>${method.description}</li>
</#list>
</#if>
 * </ul>
 * </p>
 *
 * <p>Note: The repository interface is a core interface of the domain layer; implementations should be placed in the infrastructure layer (infrastructure/persistence/repository/).</p>
 *
 * @author ${author}
 * @since ${date}
 */
interface ${entity}Repository {

    /**
     * <p>Save ${table.comment} aggregate</p>
     *
     * <p>Save or update ${table.comment} aggregate root. If the aggregate root already exists, update it; otherwise, create a new aggregate root.</p>
     *
     * @param ${entity?substring(0,1)?lower_case}${entity?substring(1)} ${table.comment} aggregate root object
     * @return ${table.comment} aggregate root object
     */
    fun save(${entity?substring(0,1)?lower_case}${entity?substring(1)}: ${entity}): ${entity}

    /**
     * <p>Find ${table.comment} aggregate by ID</p>
     *
     * <p>Find the corresponding ${table.comment} aggregate by aggregate root ID. Returns null if not found.</p>
     *
     * @param id ${table.comment} aggregate root ID
     * @return ${table.comment} aggregate root object, returns null if not found
     */
    fun findById(id: Long): ${entity}?

    /**
     * <p>Delete ${table.comment} aggregate</p>
     *
     * <p>Delete ${table.comment} aggregate by aggregate root ID. The delete operation will cascade delete all entities within the aggregate.</p>
     *
     * @param id ${table.comment} aggregate root ID
     */
    fun deleteById(id: Long)

    /**
     * <p>Find all ${table.comment} aggregates</p>
     *
     * <p>Query all ${table.comment} aggregate root list. Note: For large data scenarios, use paginated queries.</p>
     *
     * @return ${table.comment} aggregate root list
     */
    fun findAll(): List<${entity}>

    /**
     * <p>Batch save ${table.comment} aggregates</p>
     *
     * <p>Batch save or update ${table.comment} aggregate root list.</p>
     *
     * @param ${entity?substring(0,1)?lower_case}${entity?substring(1)}List ${table.comment} aggregate root list
     * @return Saved ${table.comment} aggregate root list
     */
    fun saveAll(${entity?substring(0,1)?lower_case}${entity?substring(1)}List: List<${entity}>): List<${entity}>

    /**
     * <p>Batch delete ${table.comment} aggregates</p>
     *
     * <p>Batch delete ${table.comment} aggregates by aggregate root ID list.</p>
     *
     * @param ids ${table.comment} aggregate root ID list
     */
    fun deleteAllByIds(ids: List<Long>)

    /**
     * <p>Check if ${table.comment} aggregate exists</p>
     *
     * <p>Check if ${table.comment} aggregate exists by aggregate root ID.</p>
     *
     * @param id ${table.comment} aggregate root ID
     * @return Boolean whether it exists
     */
    fun existsById(id: Long): Boolean

    /**
     * <p>Count ${table.comment} aggregates</p>
     *
     * <p>Count the total number of ${table.comment} aggregate roots.</p>
     *
     * @return Long ${table.comment} aggregate root count
     */
    fun count(): Long
<#if customMethods??>

## ----------  BEGIN Custom methods  ----------
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
<#if method.exceptions??>
<#list method.exceptions as exception>
     * @exception ${exception.type} ${exception.description}
</#list>
</#if>
     */
    fun ${method.name}(<#list method.parameters as param>${param.name}: ${param.type}<#if param_has_next>, </#if></#list>): ${method.returnType}
</#list>
## ----------  END Custom methods  ----------
</#if>
}