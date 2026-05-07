package ${package.Entity}

import com.baomidou.mybatisplus.annotation.*
<#if swagger>
import io.swagger.v3.oas.annotations.media.Schema
</#if>
import java.io.Serializable
import java.time.LocalDateTime

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
<#if table.convert>
@TableName("${schemaName}${table.name}")
</#if>
<#if swagger>
@Schema(description = "${table.comment}")
</#if>
<#if superEntityClass??>
class ${entity} : ${superEntityClass}() {
<#elseif activeRecord>
class ${entity} : Model<${entity}>() {
<#else>
<#if entityLombokModel>
data class ${entity}(
<#else>
class ${entity} : Serializable {
</#if>
</#if>

<#if serialVersionUID>
    companion object {
        private const val serialVersionUID: Long = 1L
    }
</#if>
## ----------  BEGIN Field loop iteration  ----------
<#if entityLombokModel>
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
    var ${field.propertyName}: ${field.propertyType}<#if field.propertyType == "String">?</#if><#if field.keyFlag && keyStrategy == "AUTO"> = null<#elseif field.propertyType == "String"> = null<#elseif field.propertyType == "Long" || field.propertyType == "Integer" || field.propertyType == "Int"> = 0<#elseif field.propertyType == "Boolean"> = false<#elseif field.propertyType == "LocalDateTime"> = null</#if><#if field_has_next>,</#if>

</#list>
) : Serializable
<#else>
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
    var ${field.propertyName}: ${field.propertyType}<#if field.propertyType == "String">?</#if> = <#if field.keyFlag && keyStrategy == "AUTO">null<#elseif field.propertyType == "String">null<#elseif field.propertyType == "Long" || field.propertyType == "Integer" || field.propertyType == "Int">0<#elseif field.propertyType == "Boolean">false<#elseif field.propertyType == "LocalDateTime">null<#else>null</#if>

</#list>
</#if>
## ----------  END Field loop iteration  ----------
}