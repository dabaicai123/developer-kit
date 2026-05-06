PLUGIN_DIR = plugins/developer-kit-java
SKILLS_DIR = .claude/skills
AGENTS_DIR = .claude/agents
COMMANDS_DIR = .claude/commands
RULES_DIR = .claude/rules

.PHONY: install list status uninstall

# Install all plugin components into current project's .claude/ directory
install:
	@echo "Installing developer-kit-java plugin..."
	@mkdir -p $(SKILLS_DIR) $(AGENTS_DIR) $(COMMANDS_DIR) $(RULES_DIR)
	@cp -r $(PLUGIN_DIR)/skills/* $(SKILLS_DIR)/
	@cp $(PLUGIN_DIR)/agents/*.md $(AGENTS_DIR)/
	@cp $(PLUGIN_DIR)/commands/*.md $(COMMANDS_DIR)/
	@cp $(PLUGIN_DIR)/rules/*.md $(RULES_DIR)/
	@echo "Installed developer-kit-java plugin successfully."
	@echo "  Skills:   $(SKILLS_DIR)/"
	@echo "  Agents:   $(AGENTS_DIR)/"
	@echo "  Commands: $(COMMANDS_DIR)/"
	@echo "  Rules:    $(RULES_DIR)/"

# List installed components
list:
	@echo "Skills:"
	@ls $(SKILLS_DIR)/*/SKILL.md 2>/dev/null | sed 's/.*\/skills\//  /' | sed 's/SKILL.md//' || echo "  (none)"
	@echo "Agents:"
	@ls $(AGENTS_DIR)/*.md 2>/dev/null | sed 's/.*\/agents\//  /' || echo "  (none)"
	@echo "Commands:"
	@ls $(COMMANDS_DIR)/*.md 2>/dev/null | sed 's/.*\/commands\//  /' || echo "  (none)"
	@echo "Rules:"
	@ls $(RULES_DIR)/*.md 2>/dev/null | sed 's/.*\/rules\//  /' || echo "  (none)"

# Show status of what's installed vs what's available
status:
	@echo "Available in plugin:"
	@cat $(PLUGIN_DIR)/.claude-plugin/plugin.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'  Skills:   {len(d[\"skills\"])}'); print(f'  Agents:   {len(d[\"agents\"])}'); print(f'  Commands: {len(d[\"commands\"])}')"
	@echo "Installed in project:"
	@echo "  Skills:   $(shell ls $(SKILLS_DIR)/*/SKILL.md 2>/dev/null | wc -l)"
	@echo "  Agents:   $(shell ls $(AGENTS_DIR)/*.md 2>/dev/null | wc -l)"
	@echo "  Commands: $(shell ls $(COMMANDS_DIR)/*.md 2>/dev/null | wc -l)"
	@echo "  Rules:    $(shell ls $(RULES_DIR)/*.md 2>/dev/null | wc -l)"

# Remove installed components
uninstall:
	@echo "Removing developer-kit-java plugin components..."
	@rm -rf $(SKILLS_DIR)
	@rm -f $(AGENTS_DIR)/*.md
	@rm -f $(COMMANDS_DIR)/*.md
	@rm -f $(RULES_DIR)/*.md
	@echo "Plugin removed."