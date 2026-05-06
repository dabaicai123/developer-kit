package ${package.Domain}.model.valueobject

import java.io.Serializable
<#if swagger>
import io.swagger.v3.oas.annotations.media.Schema
</#if>

/**
 * <p>${valueObjectName} value object</p>
 *
 * <p>${valueObjectDescription}. Value objects are immutable and compared by value equality.
 * Value objects have no unique identifier; they are identified by their attribute values.</p>
 *
 * <p>Value object characteristics:
 * <ul>
 *   <li>Immutability: Value objects cannot be modified after creation</li>
 *   <li>Value equality: Compared by attribute values rather than reference</li>
 *   <li>No unique identifier: Value objects have no ID, identified by attribute values</li>
 *   <li>Self-contained: Value objects contain complete business meaning</li>
 * </ul>
 * </p>
 *
 * @author ${author}
 * @since ${date}
 */
<#if swagger>
@Schema(description = "${valueObjectDescription}")
</#if>
data class ${valueObjectName} private constructor(
<#-- BEGIN Value object fields -->
<#list valueObjectFields as field>
<#if field.comment?? && field.comment != "">
    /**
     * <p>${field.comment}</p>
     *
     * <p>${field.comment}, ${field.type} type</p>
     */
<#else>
    /**
     * <p>${field.propertyName}</p>
     */
</#if>
<#if swagger>
    @Schema(description = "${field.comment}")
</#if>
    val ${field.propertyName}: ${field.propertyType}<#if field.propertyType == "String">?</#if><#if field_has_next>,</#if>

</#list>
<#-- END Value object fields -->
) : Serializable {

    companion object {
        private const val serialVersionUID: Long = 1L

        /**
         * <p>Create ${valueObjectName} value object</p>
         *
         * <p>Create a new ${valueObjectName} value object instance. Value objects cannot be modified after creation.</p>
         *
<#list valueObjectFields as field>
         * @param ${field.propertyName} ${field.comment}
</#list>
         * @return ${valueObjectName} value object instance
         */
        fun create(<#list valueObjectFields as field>${field.propertyName}: ${field.propertyType}<#if field.propertyType == "String">?</#if><#if field_has_next>, </#if></#list>): ${valueObjectName} {
            return ${valueObjectName}(
<#list valueObjectFields as field>
                ${field.propertyName}<#if field_has_next>,</#if>
</#list>
            )
        }
    }
}