package ${package.Domain}.model.valueobject;

import java.io.Serializable;
<#if swagger>
import io.swagger.v3.oas.annotations.media.Schema;
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
public class ${valueObjectName} implements Serializable {

    private static final long serialVersionUID = 1L;

## ----------  BEGIN Value object fields  ----------
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
    private final ${field.propertyType} ${field.propertyName};
</#list>
## ----------  END Value object fields  ----------

    /**
     * <p>Create ${valueObjectName} value object</p>
     *
     * <p>Create a new ${valueObjectName} value object instance. Value objects cannot be modified after creation.</p>
     *
<#list valueObjectFields as field>
     * @param ${field.propertyName} ${field.comment}
</#list>
     */
    public ${valueObjectName}(<#list valueObjectFields as field>${field.propertyType} ${field.propertyName}<#if field_has_next>, </#if></#list>) {
        // TODO: Implement value object construction logic, including parameter validation
<#list valueObjectFields as field>
        this.${field.propertyName} = ${field.propertyName};
</#list>
    }

## ----------  BEGIN Getter methods  ----------
<#list valueObjectFields as field>
    /**
     * <p>Get ${field.comment}</p>
     *
     * @return ${field.propertyType} ${field.comment}
     */
    public ${field.propertyType} get${field.propertyName?substring(0,1)?upper_case}${field.propertyName?substring(1)}() {
        return ${field.propertyName};
    }
</#list>
## ----------  END Getter methods  ----------

    /**
     * <p>Value equality comparison</p>
     *
     * <p>Value objects compare equality by attribute values rather than reference comparison.</p>
     *
     * @param obj Object to compare
     * @return boolean whether equal
     */
    @Override
    public boolean equals(Object obj) {
        if (this == obj) {
            return true;
        }
        if (obj == null || getClass() != obj.getClass()) {
            return false;
        }
        ${valueObjectName} that = (${valueObjectName}) obj;
        // TODO: Implement attribute value comparison logic
<#list valueObjectFields as field>
<#if field.propertyType == "String">
        if (${field.propertyName} != null ? !${field.propertyName}.equals(that.${field.propertyName}) : that.${field.propertyName} != null) {
            return false;
        }
<#else>
        if (${field.propertyName} != that.${field.propertyName}) {
            return false;
        }
</#if>
</#list>
        return true;
    }

    /**
     * <p>Calculate hash code</p>
     *
     * <p>The hash code of a value object is calculated based on all attribute values.</p>
     *
     * @return int hash code
     */
    @Override
    public int hashCode() {
        // TODO: Implement hash code calculation logic
        int result = 17;
<#list valueObjectFields as field>
<#if field.propertyType == "String">
        result = 31 * result + (${field.propertyName} != null ? ${field.propertyName}.hashCode() : 0);
<#else>
        result = 31 * result + (int) (${field.propertyName} ^ (${field.propertyName} >>> 32));
</#if>
</#list>
        return result;
    }

    /**
     * <p>Convert to string</p>
     *
     * @return String string representation
     */
    @Override
    public String toString() {
        return "${valueObjectName}{" +
<#list valueObjectFields as field>
                "${field.propertyName}=" + ${field.propertyName} +
<#if field_has_next> ", " + </#if>
</#list>
                '}';
    }
}