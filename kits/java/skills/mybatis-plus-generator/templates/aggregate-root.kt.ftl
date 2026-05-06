package ${package.Domain}.model.aggregate.${entity?lower_case}

import java.io.Serializable
import java.time.LocalDateTime
<#if swagger>
import io.swagger.v3.oas.annotations.media.Schema
</#if>

/**
 * <p>${table.comment} aggregate root</p>
 *
 * <p>Root entity of the ${table.comment} aggregate, serving as the entry point, responsible for maintaining business invariants within the aggregate.
 * The aggregate root encapsulates core business logic and rules of ${table.comment}, ensuring data consistency.</p>
 *
 * <p>Primary responsibilities:
 * <ul>
 *   <li>Maintain business invariants within the aggregate</li>
 *   <li>Encapsulate business logic and business rules</li>
 *   <li>Manage entities and value objects within the aggregate</li>
 *   <li>Publish domain events</li>
<#list table.fields as field>
<#if field.keyFlag>
 *   <li>${field.comment}: unique identifier of the aggregate root</li>
</#if>
</#list>
 * </ul>
 * </p>
 *
 * <p>Note: The aggregate root is the core of the domain model and should not contain persistence-related annotations. Persistence entities should be placed in the infrastructure layer.</p>
 *
 * @author ${author}
 * @since ${date}
 */
<#if swagger>
@Schema(description = "${table.comment} aggregate root")
</#if>
class ${entity} : Serializable {

    companion object {
        private const val serialVersionUID: Long = 1L

        /**
         * <p>Create ${table.comment} aggregate root</p>
         *
         * <p>Create a new ${table.comment} aggregate root instance. This method should include necessary business rule validation.</p>
         *
         * @return ${table.comment} aggregate root instance
         */
        fun create(): ${entity} {
            return ${entity}()
        }
    }

<#-- BEGIN Aggregate root fields -->
<#list table.fields as field>
<#if field.keyFlag>
<#assign keyPropertyName=field.propertyName>
</#if>
<#if field.comment?? && field.comment != "">
    /**
     * <p>${field.comment}</p>
     *
     * <p>${field.comment}, <#if field.keyFlag>the unique identifier of the aggregate root, </#if>used to identify the ${table.comment} aggregate.</p>
     */
<#else>
    /**
     * <p>${field.propertyName}</p>
     */
</#if>
<#if swagger>
    @Schema(description = "${field.comment}")
</#if>
    var ${field.propertyName}: ${field.propertyType}? = null

</#list>
<#-- END Aggregate root fields -->
    /**
     * <p>Update ${table.comment} information</p>
     *
     * <p>Update ${table.comment} aggregate root information. This method should include business rule validation.</p>
     *
     * @param ${entity?substring(0,1)?lower_case}${entity?substring(1)} ${table.comment} aggregate root object
     */
    fun update(${entity?substring(0,1)?lower_case}${entity?substring(1)}: ${entity}) {
        TODO("Implement update() with business invariants and domain event publishing")
    }

    /**
     * <p>Delete ${table.comment}</p>
     *
     * <p>Mark ${table.comment} aggregate root as deleted. This method should include business rule validation.</p>
     */
    fun delete() {
        TODO("Implement delete() with relationship checks and domain event publishing")
    }
}