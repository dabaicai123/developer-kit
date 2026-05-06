package ${package.Domain}.model.aggregate.${entity?lower_case};

import java.io.Serializable;
import java.time.LocalDateTime;
<#if swagger>
import io.swagger.v3.oas.annotations.media.Schema;
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
public class ${entity} implements Serializable {

    private static final long serialVersionUID = 1L;

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
    private ${field.propertyType} ${field.propertyName};
</#list>
<#-- END Aggregate root fields -->
    /**
     * <p>Create ${table.comment} aggregate root</p>
     *
     * <p>Create a new ${table.comment} aggregate root instance. This method should include necessary business rule validation.</p>
     *
     * @return ${table.comment} aggregate root instance
     */
    public static ${entity} create() {
        ${entity} ${entity?substring(0,1)?lower_case}${entity?substring(1)} = new ${entity}();
        return ${entity?substring(0,1)?lower_case}${entity?substring(1)};
    }

    /**
     * <p>Update ${table.comment} information</p>
     *
     * <p>Update ${table.comment} aggregate root information. This method should include business rule validation.</p>
     *
     * @param ${entity?substring(0,1)?lower_case}${entity?substring(1)} ${table.comment} aggregate root object
     */
    public void update(${entity} ${entity?substring(0,1)?lower_case}${entity?substring(1)}) {
        throw new UnsupportedOperationException("Implement update() with business invariants and domain event publishing");
    }

    /**
     * <p>Delete ${table.comment}</p>
     *
     * <p>Mark ${table.comment} aggregate root as deleted. This method should include business rule validation.</p>
     */
    public void delete() {
        throw new UnsupportedOperationException("Implement delete() with relationship checks and domain event publishing");
    }

<#-- BEGIN Getter/Setter methods -->
<#list table.fields as field>
    /**
     * <p>Get ${field.comment}</p>
     *
     * @return ${field.propertyType} ${field.comment}
     */
    public ${field.propertyType} get${field.propertyName?substring(0,1)?upper_case}${field.propertyName?substring(1)}() {
        return ${field.propertyName};
    }

    /**
     * <p>Set ${field.comment}</p>
     *
     * @param ${field.propertyName} ${field.comment}
     */
    public void set${field.propertyName?substring(0,1)?upper_case}${field.propertyName?substring(1)}(${field.propertyType} ${field.propertyName}) {
        this.${field.propertyName} = ${field.propertyName};
    }
</#list>
<#-- END Getter/Setter methods -->
}