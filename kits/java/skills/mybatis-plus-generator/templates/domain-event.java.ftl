package ${package.Domain}.model.event;

import java.io.Serializable;
import java.time.LocalDateTime;

/**
 * <p>${eventName} domain event</p>
 *
 * <p>${eventDescription}. Domain events represent important business events that occur in the domain model.
 * Domain events are part of the domain layer, used to achieve decoupled communication between domain objects.</p>
 *
 * <p>Domain event characteristics:
 * <ul>
 *   <li>Immutability: Domain events cannot be modified after creation</li>
 *   <li>Timestamp: Records when the event occurred</li>
 *   <li>Event source: Records the aggregate root information that triggered the event</li>
 *   <li>Event data: Contains business data related to the event</li>
 * </ul>
 * </p>
 *
 * @author ${author}
 * @since ${date}
 */
public class ${eventName} implements Serializable {

    private static final long serialVersionUID = 1L;

    /**
     * <p>Event ID</p>
     *
     * <p>Unique identifier of the event</p>
     */
    private String eventId;

    /**
     * <p>Aggregate root ID</p>
     *
     * <p>ID of the aggregate root that triggered the event</p>
     */
    private Long aggregateId;

    /**
     * <p>Event occurrence time</p>
     *
     * <p>Timestamp recording when the event occurred</p>
     */
    private LocalDateTime occurredOn;

<#-- BEGIN Event data fields -->
<#list eventFields as field>
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
    private ${field.propertyType} ${field.propertyName};
</#list>
<#-- END Event data fields -->
    /**
     * <p>Create ${eventName} domain event</p>
     *
     * <p>Create a new ${eventName} domain event instance.</p>
     *
     * @param aggregateId Aggregate root ID
<#list eventFields as field>
     * @param ${field.propertyName} ${field.comment}
</#list>
     * @return ${eventName} domain event instance
     */
    public static ${eventName} create(Long aggregateId<#list eventFields as field>, ${field.propertyType} ${field.propertyName}</#list>) {
        ${eventName} event = new ${eventName}();
        event.eventId = java.util.UUID.randomUUID().toString();
        event.aggregateId = aggregateId;
        event.occurredOn = LocalDateTime.now();
<#list eventFields as field>
        event.${field.propertyName} = ${field.propertyName};
</#list>
        return event;
    }

<#-- BEGIN Getter methods -->
    /**
     * <p>Get event ID</p>
     *
     * @return String event ID
     */
    public String getEventId() {
        return eventId;
    }

    /**
     * <p>Get aggregate root ID</p>
     *
     * @return Long aggregate root ID
     */
    public Long getAggregateId() {
        return aggregateId;
    }

    /**
     * <p>Get event occurrence time</p>
     *
     * @return LocalDateTime event occurrence time
     */
    public LocalDateTime getOccurredOn() {
        return occurredOn;
    }

<#list eventFields as field>
    /**
     * <p>Get ${field.comment}</p>
     *
     * @return ${field.propertyType} ${field.comment}
     */
    public ${field.propertyType} get${field.propertyName?substring(0,1)?upper_case}${field.propertyName?substring(1)}() {
        return ${field.propertyName};
    }
</#list>
<#-- END Getter methods -->
    /**
     * <p>Convert to string</p>
     *
     * @return String string representation
     */
    @Override
    public String toString() {
        return "${eventName}{" +
                "eventId='" + eventId + '\'' +
                ", aggregateId=" + aggregateId +
                ", occurredOn=" + occurredOn +
<#list eventFields as field>
                ", ${field.propertyName}=" + ${field.propertyName} +
</#list>
                '}';
    }
}