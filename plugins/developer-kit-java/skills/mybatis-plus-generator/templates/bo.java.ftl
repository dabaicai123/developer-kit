package ${package.BO};

<#if swagger>
import io.swagger.v3.oas.annotations.media.Schema;
</#if>
<#if entityLombokModel>
import lombok.Data;
</#if>
import java.io.Serializable;

/**
 * <p>${table.comment} business object</p>
 *
 * <p>Business logic object that encapsulates ${table.comment}, containing business rules and business methods.
 * This BO is used for business layer processing, including business logic and business rule validation.</p>
 *
 * @author ${author}
 * @since ${date}
 */
<#if swagger>
@Schema(description = "${table.comment} business object")
</#if>
<#if entityLombokModel>
@Data
</#if>
public class ${entity}BO implements Serializable {

<#if serialVersionUID>
    private static final long serialVersionUID = 1L;
</#if>
## ----------  BEGIN BO fields  ----------
<#list boFields as field>
<#if field.comment?? && field.comment != "">
    /**
     * <p>${field.comment}</p>
     *
     * <p>${field.comment}, used for business logic processing</p>
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
## ----------  END BO fields  ----------
}