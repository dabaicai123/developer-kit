package ${package.Entity};

import com.baomidou.mybatisplus.annotation.*;
<#if swagger>
import io.swagger.v3.oas.annotations.media.Schema;
</#if>
<#if entityLombokModel>
import lombok.Data;
import lombok.EqualsAndHashCode;
</#if>
import java.io.Serializable;
import java.time.LocalDateTime;

/**
 * <p>${table.comment} entity class</p>
 *
 * <p>Corresponding to the ${table.name} table in the database, used to store ${table.comment}.
 * This entity class uses MyBatis-Plus annotations for ORM mapping, supporting auto table creation and field mapping.</p>
 *
 * <p>Primary fields:
 * <ul>
<#list table.fields as field>
 *   <li>${field.propertyName}: ${field.comment}</li>
</#list>
 * </ul>
 * </p>
 *
 * @author ${author}
 * @since ${date}
 */
<#if entityLombokModel>
@Data
<#if superEntityClass??>
@EqualsAndHashCode(callSuper = true)
<#else>
@EqualsAndHashCode(callSuper = false)
</#if>
</#if>
<#if table.convert>
@TableName("${schemaName}${table.name}")
</#if>
<#if swagger>
@Schema(description = "${table.comment}")
</#if>
<#if superEntityClass??>
public class ${entity} extends ${superEntityClass} {
<#elseif activeRecord>
public class ${entity} extends Model<${entity}> {
<#else>
public class ${entity} implements Serializable {
</#if>

<#if serialVersionUID>
    private static final long serialVersionUID = 1L;
</#if>
## ----------  BEGIN Field loop iteration  ----------
<#list table.fields as field>
<#if field.keyFlag>
<#assign keyPropertyName=field.propertyName>
</#if>
<#if field.comment?? && field.comment != "">
    /**
     * <p>${field.comment}</p>
     *
     * <p>${field.comment}, ${field.type} type<#if field.propertyType == "String">, length limit of ${field.length} characters</#if></p>
     */
<#else>
    /**
     * <p>${field.propertyName}</p>
     */
</#if>
<#if swagger>
    @Schema(description = "${field.comment}")
</#if>
<#if field.keyFlag>
    @TableId(value = "${field.name}", type = IdType.${keyStrategy})
<#elseif field.fill??>
<#if field.convert>
    @TableField(value = "${field.name}", fill = FieldFill.${field.fill})
<#else>
    @TableField(fill = FieldFill.${field.fill})
</#if>
<#elseif field.convert>
    @TableField("${field.name}")
</#if>
<#if field.versionField>
    @Version
</#if>
<#if field.logicDeleteField>
    @TableLogic
</#if>
    private ${field.propertyType} ${field.propertyName};
</#list>
## ----------  END Field loop iteration  ----------
}