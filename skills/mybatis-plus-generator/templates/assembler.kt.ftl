package ${package.Interfaces}.assembler

import ${package.Domain}.model.aggregate.${entity?lower_case}.${entity}
import ${package.Interfaces}.web.dto.request.${entity}RequestDTO
import ${package.Interfaces}.web.dto.response.${entity}ResponseDTO
import ${package.Application}.dto.${entity}DTO
import org.springframework.stereotype.Component

/**
 * <p>${table.comment} DTO assembler</p>
 *
 * <p>Responsible for converting between ${table.comment} aggregate root and DTOs, located in the interfaces layer.
 * The assembler encapsulates conversion logic between domain objects and DTOs, keeping the domain model pure.</p>
 *
 * <p>Primary responsibilities:
 * <ul>
 *   <li>Convert aggregate root to DTO</li>
 *   <li>Convert DTO to aggregate root</li>
 *   <li>Handle mapping between DTOs and domain objects</li>
 * </ul>
 * </p>
 *
 * @author ${author}
 * @since ${date}
 */
@Component
class ${entity}Assembler {

    /**
     * <p>Convert aggregate root to response DTO</p>
     *
     * <p>Convert ${table.comment} aggregate root to response DTO for API responses.</p>
     *
     * @param ${entity?substring(0,1)?lower_case}${entity?substring(1)} ${table.comment} aggregate root object
     * @return ${table.comment} response DTO object
     */
    fun toResponseDTO(${entity?substring(0,1)?lower_case}${entity?substring(1)}: ${entity}?): ${entity}ResponseDTO? {
        if (${entity?substring(0,1)?lower_case}${entity?substring(1)} == null) {
            return null
        }

        val dto = ${entity}ResponseDTO()
        // TODO: Implement conversion logic from aggregate root to response DTO
<#list table.fields as field>
        dto.${field.propertyName} = ${entity?substring(0,1)?lower_case}${entity?substring(1)}.${field.propertyName}
</#list>
        return dto
    }

    /**
     * <p>Convert request DTO to aggregate root</p>
     *
     * <p>Convert request DTO to ${table.comment} aggregate root for create or update operations.</p>
     *
     * @param requestDTO ${table.comment} request DTO object
     * @return ${table.comment} aggregate root object
     */
    fun toAggregate(requestDTO: ${entity}RequestDTO?): ${entity}? {
        if (requestDTO == null) {
            return null
        }

        val ${entity?substring(0,1)?lower_case}${entity?substring(1)} = ${entity}()
        // TODO: Implement conversion logic from request DTO to aggregate root
<#list table.fields as field>
        ${entity?substring(0,1)?lower_case}${entity?substring(1)}.${field.propertyName} = requestDTO.${field.propertyName}
</#list>
        return ${entity?substring(0,1)?lower_case}${entity?substring(1)}
    }

    /**
     * <p>Convert application DTO to aggregate root</p>
     *
     * <p>Convert application layer DTO to ${table.comment} aggregate root.</p>
     *
     * @param dto ${table.comment} application DTO object
     * @return ${table.comment} aggregate root object
     */
    fun toAggregate(dto: ${entity}DTO?): ${entity}? {
        if (dto == null) {
            return null
        }

        val ${entity?substring(0,1)?lower_case}${entity?substring(1)} = ${entity}()
        // TODO: Implement conversion logic from application DTO to aggregate root
<#list table.fields as field>
        ${entity?substring(0,1)?lower_case}${entity?substring(1)}.${field.propertyName} = dto.${field.propertyName}
</#list>
        return ${entity?substring(0,1)?lower_case}${entity?substring(1)}
    }

    /**
     * <p>Convert aggregate root to application DTO</p>
     *
     * <p>Convert ${table.comment} aggregate root to application layer DTO.</p>
     *
     * @param ${entity?substring(0,1)?lower_case}${entity?substring(1)} ${table.comment} aggregate root object
     * @return ${table.comment} application DTO object
     */
    fun toDTO(${entity?substring(0,1)?lower_case}${entity?substring(1)}: ${entity}?): ${entity}DTO? {
        if (${entity?substring(0,1)?lower_case}${entity?substring(1)} == null) {
            return null
        }

        val dto = ${entity}DTO()
        // TODO: Implement conversion logic from aggregate root to application DTO
<#list table.fields as field>
        dto.${field.propertyName} = ${entity?substring(0,1)?lower_case}${entity?substring(1)}.${field.propertyName}
</#list>
        return dto
    }
}