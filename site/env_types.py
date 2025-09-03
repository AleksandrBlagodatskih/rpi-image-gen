import re
from typing import List, Optional, Dict, Any, Tuple
from validators import BaseValidator, parse_validator


# X-Env field helpers
class XEnv:
    """Helper for constructing X-Env field names consistently."""

    VAR_PREFIX = "X-Env-Var-"
    LAYER_PREFIX = "X-Env-Layer-"

    # === VARIABLE FIELD METHODS ===

    @classmethod
    def var_base(cls, name: str) -> str:
        """Build base variable field name: X-Env-Var-{name}"""
        return f"{cls.VAR_PREFIX}{name.upper()}"

    @classmethod
    def var_desc(cls, name: str) -> str:
        """Build description field name: X-Env-Var-{name}-Desc"""
        return f"{cls.VAR_PREFIX}{name.upper()}-Desc"

    @classmethod
    def var_required(cls, name: str) -> str:
        """Build required field name: X-Env-Var-{name}-Required"""
        return f"{cls.VAR_PREFIX}{name.upper()}-Required"

    @classmethod
    def var_valid(cls, name: str) -> str:
        """Build validation field name: X-Env-Var-{name}-Valid"""
        return f"{cls.VAR_PREFIX}{name.upper()}-Valid"

    @classmethod
    def var_set(cls, name: str) -> str:
        """Build set policy field name: X-Env-Var-{name}-Set"""
        return f"{cls.VAR_PREFIX}{name.upper()}-Set"

    # === PATTERN METHODS FOR SUPPORTED_FIELD_PATTERNS ===

    @classmethod
    def var_desc_pattern(cls) -> str:
        """Build description pattern: X-Env-Var-*-Desc"""
        return f"{cls.VAR_PREFIX}*-Desc"

    @classmethod
    def var_required_pattern(cls) -> str:
        """Build required pattern: X-Env-Var-*-Required"""
        return f"{cls.VAR_PREFIX}*-Required"

    @classmethod
    def var_valid_pattern(cls) -> str:
        """Build validation pattern: X-Env-Var-*-Valid"""
        return f"{cls.VAR_PREFIX}*-Valid"

    @classmethod
    def var_set_pattern(cls) -> str:
        """Build set policy pattern: X-Env-Var-*-Set"""
        return f"{cls.VAR_PREFIX}*-Set"

    @classmethod
    def var_prefix(cls) -> str:
        """Build variable prefix field: X-Env-VarPrefix"""
        return "X-Env-VarPrefix"

    @classmethod
    def var_requires(cls) -> str:
        """Build variable requirements field: X-Env-VarRequires"""
        return "X-Env-VarRequires"

    @classmethod
    def var_optional(cls) -> str:
        """Build variable optional field: X-Env-VarOptional"""
        return "X-Env-VarOptional"

    @classmethod
    def var_requires_valid(cls) -> str:
        """Build variable requirements validation field: X-Env-VarRequires-Valid"""
        return "X-Env-VarRequires-Valid"

    @classmethod
    def var_optional_valid(cls) -> str:
        """Build variable optional validation field: X-Env-VarOptional-Valid"""
        return "X-Env-VarOptional-Valid"

    @classmethod
    def is_var_field(cls, field_name: str) -> bool:
        """Check if field name is an X-Env-Var field."""
        return field_name.startswith(cls.VAR_PREFIX)

    @classmethod
    def is_base_var_field(cls, field_name: str) -> bool:
        """Check if field name is a base variable definition (no attribute suffix)."""
        if not cls.is_var_field(field_name):
            return False
        var_part = field_name[len(cls.VAR_PREFIX):]
        return '-' not in var_part

    @classmethod
    def extract_var_name(cls, field_name: str) -> Optional[str]:
        """Extract variable name from field name. Returns None if not a var field."""
        if not cls.is_var_field(field_name):
            return None
        return field_name[len(cls.VAR_PREFIX):]

    @classmethod
    def extract_base_var_name(cls, field_name: str) -> Optional[str]:
        """Extract base variable name from any X-Env-Var field (base or attribute)."""
        if not cls.is_var_field(field_name):
            return None
        var_part = field_name[len(cls.VAR_PREFIX):]

        # If it's a base field, return as-is
        if '-' not in var_part:
            return var_part

        # If it's an attribute field, extract the base part
        return var_part.split('-')[0]

    @classmethod
    def parse_var_field(cls, field_name: str) -> Optional[Tuple[str, Optional[str]]]:
        """
        Parse a var field into (base_name, attribute_suffix).

        Returns:
            - For base fields: (var_name, None)
            - For attribute fields: (var_name, suffix)
            - For non-var fields: None
        """
        if not cls.is_var_field(field_name):
            return None

        var_part = field_name[len(cls.VAR_PREFIX):]

        if '-' not in var_part:
            # Base variable field
            return (var_part, None)

        # Attribute field - split on first dash
        parts = var_part.split('-', 1)
        if len(parts) == 2:
            return (parts[0], f"-{parts[1]}")

        return (var_part, None)

    # === LAYER FIELD METHODS ===

    @classmethod
    def layer_name(cls) -> str:
        """Build layer name field: X-Env-Layer-Name"""
        return f"{cls.LAYER_PREFIX}Name"

    @classmethod
    def layer_description(cls) -> str:
        """Build layer description field: X-Env-Layer-Desc"""
        return f"{cls.LAYER_PREFIX}Desc"

    @classmethod
    def layer_version(cls) -> str:
        """Build layer version field: X-Env-Layer-Version"""
        return f"{cls.LAYER_PREFIX}Version"

    @classmethod
    def layer_category(cls) -> str:
        """Build layer category field: X-Env-Layer-Category"""
        return f"{cls.LAYER_PREFIX}Category"

    @classmethod
    def layer_requires(cls) -> str:
        """Build layer requires field: X-Env-Layer-Requires"""
        return f"{cls.LAYER_PREFIX}Requires"

    @classmethod
    def layer_provides(cls) -> str:
        """Build layer provides field: X-Env-Layer-Provides"""
        return f"{cls.LAYER_PREFIX}Provides"

    @classmethod
    def layer_requires_provider(cls) -> str:
        """Build layer requires provider field: X-Env-Layer-RequiresProvider"""
        return f"{cls.LAYER_PREFIX}RequiresProvider"

    @classmethod
    def layer_conflicts(cls) -> str:
        """Build layer conflicts field: X-Env-Layer-Conflicts"""
        return f"{cls.LAYER_PREFIX}Conflicts"

    @classmethod
    def is_layer_field(cls, field_name: str) -> bool:
        """Check if field name is an X-Env-Layer field."""
        return field_name.startswith(cls.LAYER_PREFIX)


class EnvVariable:
    """Represents an environment variable with its metadata and validation rules."""

    def __init__(self, name: str, value: str = "", description: str = "",
                 required: bool = False, validator: Optional[BaseValidator] = None,
                 validation_rule: str = "", set_policy: str = "immediate",
                 source_layer: str = "", position: int = 0):
        self.name = name
        self.value = value
        self.description = description
        self.required = required
        self.validator = validator
        self.validation_rule = validation_rule  # Original validation rule string
        self.set_policy = set_policy  # immediate, lazy, force, skip
        self.source_layer = source_layer  # Layer that defined this variable
        self.position = position  # Order within dependency processing

    @classmethod
    def from_metadata_fields(cls, var_name: str, metadata_dict: Dict[str, str],
                           prefix: str = "", source_layer: str = "", position: int = 0) -> 'EnvVariable':
        """Create an EnvVariable from metadata fields."""
        # Extract the base variable name (without X-Env-Var- prefix)
        base_name = var_name.upper()

        # Get the basic variable definition
        var_key = XEnv.var_base(base_name)
        value = metadata_dict.get(var_key, "")

        # Get additional attributes
        desc_key = XEnv.var_desc(base_name)
        description = metadata_dict.get(desc_key, "")

        required_key = XEnv.var_required(base_name)
        required_str = metadata_dict.get(required_key, "false")
        required = required_str.lower() in ("true", "1", "yes", "y")

        valid_key = XEnv.var_valid(base_name)
        valid_rule = metadata_dict.get(valid_key, "")
        validator = None
        if valid_rule:
            try:
                validator = parse_validator(valid_rule)
            except ValueError as e:
                raise ValueError(f"Invalid validation rule '{valid_rule}' for variable {var_name}: {e}")

        set_key = XEnv.var_set(base_name)
        set_raw = metadata_dict.get(set_key, "immediate")
        set_policy = cls._parse_set_policy(set_raw)

        # Calculate full variable name
        full_name = f"IGconf_{prefix}_{var_name.lower()}" if prefix else var_name

        return cls(
            name=full_name,
            value=value,
            description=description,
            required=required,
            validator=validator,
            validation_rule=valid_rule,
            set_policy=set_policy,
            source_layer=source_layer,
            position=position
        )

    @staticmethod
    def _parse_set_policy(value: Optional[str]) -> str:
        """Parse Set policy value into canonical form."""
        if value is None:
            return "immediate"
        val = str(value).strip().lower()

        if val in ["false", "0", "no", "n"]:
            return "skip"
        elif val == "lazy":
            return "lazy"
        elif val == "force":
            return "force"
        else:  # true, 1, yes, y, immediate, or anything else
            return "immediate"

    def validate_value(self, value: Optional[str] = None) -> List[str]:
        """Validate a value against this variable's validation rule."""
        if self.validator is None:
            return []  # No validation rule, so it's valid

        test_value = value if value is not None else self.value
        return self.validator.validate(test_value)

    def get_validation_description(self) -> str:
        """Get a human-readable description of the validation rule."""
        if self.validator is None:
            return "No validation rule"
        return self.validator.describe()

    def should_set_in_environment(self) -> bool:
        """Check if this variable should be set in the environment."""
        return self.set_policy != "skip"

    def __repr__(self) -> str:
        return f"EnvVariable(name='{self.name}', value='{self.value}', policy='{self.set_policy}', layer='{self.source_layer}', pos={self.position})"


class EnvLayer:
    """Represents a layer with its dependencies and metadata."""

    def __init__(self, name: str, description: str = "", version: str = "1.0.0",
                 category: str = "general", deps: List[str] = None,
                 provides: List[str] = None, requires_provider: List[str] = None,
                 conflicts: List[str] = None, config_file: str = ""):
        self.name = name
        self.description = description
        self.version = version
        self.category = category
        self.deps = deps or []
        self.provides = provides or []
        self.requires_provider = requires_provider or []
        self.conflicts = conflicts or []
        self.config_file = config_file

    @classmethod
    def from_metadata_fields(cls, metadata_dict: Dict[str, str],
                           filepath: str = "") -> Optional['EnvLayer']:
        """Create an EnvLayer from metadata fields."""
        # Check if this has layer information
        layer_name = metadata_dict.get(XEnv.layer_name(), "")
        if not layer_name:
            return None

        # Validate all X-Env-Layer fields against supported schema
        cls._validate_layer_fields(metadata_dict, filepath)

        description = metadata_dict.get(XEnv.layer_description(), "")
        version = metadata_dict.get(XEnv.layer_version(), "1.0.0")
        category = metadata_dict.get(XEnv.layer_category(), "general")

        # Parse dependency lists
        requires_str = metadata_dict.get(XEnv.layer_requires(), "")
        requires = cls._parse_dependency_list(requires_str)

        provides_str = metadata_dict.get(XEnv.layer_provides(), "")
        provides = cls._parse_dependency_list(provides_str)

        requires_provider_str = metadata_dict.get(XEnv.layer_requires_provider(), "")
        requires_provider = cls._parse_dependency_list(requires_provider_str)

        conflicts_str = metadata_dict.get(XEnv.layer_conflicts(), "")
        conflicts = cls._parse_dependency_list(conflicts_str)

        # Infer config file from filepath if not provided
        import os
        config_file = os.path.basename(filepath) if filepath else f"{layer_name}.yaml"

        return cls(
            name=layer_name,
            description=description,
            version=version,
            category=category,
            deps=requires,
            provides=provides,
            requires_provider=requires_provider,
            conflicts=conflicts,
            config_file=config_file
        )

    @staticmethod
    def _parse_dependency_list(depends_str: str) -> List[str]:
        """Parse dependency string into list of layer names/IDs with environment variable evaluation."""
        if not depends_str.strip():
            return []

        import re
        deps = []
        for dep in depends_str.split(','):
            dep_name = dep.strip()
            if dep_name:
                # Find and evaluate environment variables in dependency names
                if '${' in dep_name:
                    dep_name = EnvLayer._evaluate_env_variables(dep_name)

                # Validate dependency name format
                if re.search(r"\s", dep_name):
                    raise ValueError(
                        f"Invalid dependency token '{dep_name}' - dependencies must be comma-separated without spaces/newlines inside a token")
                if not re.match(r'^[A-Za-z0-9_-]+$', dep_name):
                    raise ValueError(f"Invalid dependency name '{dep_name}' - only alphanum, dash, underscore allowed")
                deps.append(dep_name)
        return deps

    @staticmethod
    def _evaluate_env_variables(text: str) -> str:
        """Evaluate ${VAR} environment variable substitutions in text."""
        import re
        import os

        def replacer(match):
            var_name = match.group(1)
            env_value = os.environ.get(var_name)
            if env_value is None:
                raise ValueError(f"Environment variable '{var_name}' not found for dependency evaluation")
            return env_value

        return re.sub(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\}', replacer, text)

    @classmethod
    def _validate_layer_fields(cls, metadata_dict: Dict[str, str], filepath: str = "") -> None:
        """Validate that all X-Env-Layer fields are supported according to the schema"""
        # Import here to avoid circular imports
        try:
            from metadata_parser import SUPPORTED_FIELD_PATTERNS
        except ImportError:
            # If we can't import the schema, skip validation
            return

        # Get all X-Env-Layer fields from metadata
        layer_fields = {key: value for key, value in metadata_dict.items()
                       if key.startswith(XEnv.LAYER_PREFIX)}

        # Check each field against supported patterns
        for field_name in layer_fields.keys():
            if field_name not in SUPPORTED_FIELD_PATTERNS:
                # Check if it matches any pattern-based fields (shouldn't for layers, but be thorough)
                supported = False
                for pattern_key in SUPPORTED_FIELD_PATTERNS.keys():
                    if '*' in pattern_key and field_name.startswith(pattern_key.split('*')[0]):
                        supported = True
                        break

                if not supported:
                    filename = filepath.split('/')[-1] if filepath else "unknown"
                    raise ValueError(f"Unsupported layer field '{field_name}' in {filename}")

    def get_all_dependencies(self) -> List[str]:
        """Get all dependencies (only actual requires, not provider requirements)."""
        return self.deps

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary format for API compatibility."""
        return {
            "name": self.name,
            "description": self.description,
            "version": self.version,
            "category": self.category,
            "depends": self.deps,
            "optional_depends": [],  # Not currently supported
            "conflicts": self.conflicts,
            "config_file": self.config_file,
            "provides": self.provides,
            "provider_requires": self.requires_provider,
        }

    def __repr__(self) -> str:
        return f"EnvLayer(name='{self.name}', deps={self.deps}, provides={self.provides})"


class MetadataContainer:
    """Container for parsed metadata with variables and layer information."""

    def __init__(self, filepath: str = ""):
        self.filepath = filepath
        self.variables: Dict[str, EnvVariable] = {}
        self.layer: Optional[EnvLayer] = None
        self.var_prefix: str = ""
        self.required_vars: List[str] = []
        self.optional_vars: List[str] = []
        self.raw_metadata: Dict[str, str] = {}

    @classmethod
    def from_metadata_dict(cls, metadata_dict: Dict[str, str],
                          filepath: str = "") -> 'MetadataContainer':
        """Create a MetadataContainer from a metadata dictionary."""
        container = cls(filepath)
        container.raw_metadata = metadata_dict.copy()

        # Apply placeholder substitution to the metadata
        container.apply_placeholders()

        # Extract prefix
        container.var_prefix = container.raw_metadata.get(XEnv.var_prefix(), "").lower()

        # Extract layer information
        container.layer = EnvLayer.from_metadata_fields(container.raw_metadata, filepath)

        # Extract variables
        for key in container.raw_metadata.keys():
            if XEnv.is_base_var_field(key):
                # This is a base variable definition
                var_name = XEnv.extract_base_var_name(key)
                try:
                    # Note: source_layer and position will be set later by LayerManager
                    env_var = EnvVariable.from_metadata_fields(
                        var_name, container.raw_metadata, container.var_prefix,
                        source_layer="", position=0
                    )
                    container.variables[env_var.name] = env_var
                except ValueError as e:
                    # Re-raise to fail layer loading
                    raise ValueError(f"Invalid specifier for variable {var_name}: {e}")
                except Exception as e:
                    # Skip other types of errors - they'll be caught during validation
                    pass

        # Extract required/optional environment variable lists
        required_vars_str = container.raw_metadata.get(XEnv.var_requires(), "")
        if required_vars_str.strip():
            container.required_vars = [v.strip() for v in required_vars_str.split(',') if v.strip()]

        optional_vars_str = container.raw_metadata.get(XEnv.var_optional(), "")
        if optional_vars_str.strip():
            container.optional_vars = [v.strip() for v in optional_vars_str.split(',') if v.strip()]

        return container

    def get_settable_variables(self) -> Dict[str, EnvVariable]:
        """Get variables that should be set according to their Set directive."""
        return {name: var for name, var in self.variables.items()
                if var.should_set_in_environment()}

    def has_layer_info(self) -> bool:
        """Check if this container has layer information."""
        return self.layer is not None

    def _build_placeholders(self) -> Dict[str, str]:
        """Return dict with placeholder values for this file."""
        import os
        abs_path = os.path.abspath(self.filepath)
        return {
            "FILENAME": os.path.basename(abs_path),
            "DIRECTORY": os.path.dirname(abs_path),
            "FILEPATH": abs_path,
        }

    def _substitute_placeholders(self, text: str, placeholders: Dict[str, str]) -> str:
        """Replace ${NAME} in text with corresponding placeholder."""
        if "${" not in text:
            return text

        # Handle escaped \${...}
        ESCAPE_TOKEN = "<<LITERAL_DOLLAR_BRACE>>"
        text_escaped = text.replace("\\${", ESCAPE_TOKEN)

        def _repl(match):
            key = match.group(1)
            return placeholders.get(key, match.group(0))

        substituted = re.sub(r"\$\{([A-Z][A-Z0-9_]*)\}", _repl, text_escaped)
        return substituted.replace(ESCAPE_TOKEN, "${")

    def apply_placeholders(self):
        """Walk metadata and substitute placeholders in all string fields."""
        placeholders = self._build_placeholders()

        if not self.raw_metadata:
            return

        for key in list(self.raw_metadata.keys()):
            val = self.raw_metadata[key]
            if isinstance(val, str):
                self.raw_metadata[key] = self._substitute_placeholders(val, placeholders)

    def __repr__(self) -> str:
        return f"MetadataContainer(vars={len(self.variables)}, layer={self.layer is not None})"


class VariableResolver:
    """Resolves final variable values from multiple definitions using policy rules."""

    def __init__(self):
        pass

    def resolve(self, variable_definitions: Dict[str, List[EnvVariable]]) -> Dict[str, EnvVariable]:
        """
        Resolve final variable values using policy rules:
        a) If any variable is defined as force, use the last force definition.
        b) Else if any immediate, use the first one provided the variable is not set in the env.
        c) If lazy, use the last one provided the variable is not set in the env.

        Args:
            variable_definitions: Dict mapping variable names to lists of EnvVariable definitions

        Returns:
            Dict mapping variable names to the resolved EnvVariable instance in layer dependency order
        """
        import os
        resolved = {}

        # Get all variables and sort by their earliest position to maintain layer dependency order
        all_vars = []
        for var_name, definitions in variable_definitions.items():
            if definitions:
                earliest_position = min(d.position for d in definitions)
                all_vars.append((var_name, definitions, earliest_position))

        # Sort by earliest position to maintain layer dependency order
        all_vars.sort(key=lambda x: x[2])

        for var_name, definitions, _ in all_vars:
            resolved_var = self._resolve_single_variable(var_name, definitions)
            if resolved_var:
                resolved[var_name] = resolved_var
            elif var_name in os.environ:
                # Variable is in environment - create a special entry for skip message
                # Use the first definition for source layer info
                first_def = definitions[0]
                env_var = EnvVariable(
                    name=var_name,
                    value=os.environ[var_name],
                    description=first_def.description,
                    required=first_def.required,
                    validator=first_def.validator,
                    set_policy="already_set",  # Special policy for environment variables
                    source_layer=first_def.source_layer,
                    position=first_def.position
                )
                resolved[var_name] = env_var

        return resolved

    def _resolve_single_variable(self, var_name: str, definitions: List[EnvVariable]) -> Optional[EnvVariable]:
        """Resolve a single variable using policy rules."""
        import os

        # Separate definitions by policy
        force_defs = [d for d in definitions if d.set_policy == "force"]
        immediate_defs = [d for d in definitions if d.set_policy == "immediate"]
        lazy_defs = [d for d in definitions if d.set_policy == "lazy"]

        # Rule a: If any variable is defined as force, use the last force definition
        if force_defs:
            return self._get_last_by_position(force_defs)

        # Rule b: Else if any immediate, use the first one provided the variable is not set in the env
        elif immediate_defs and var_name not in os.environ:
            return self._get_first_by_position(immediate_defs)

        # Rule c: If lazy, use the last one provided the variable is not set in the env
        elif lazy_defs and var_name not in os.environ:
            return self._get_last_by_position(lazy_defs)

        # Variable is set in environment or no applicable definitions
        return None

    def _get_first_by_position(self, definitions: List[EnvVariable]) -> EnvVariable:
        """Get the definition with the earliest position (first in dependency order)."""
        return min(definitions, key=lambda d: d.position)

    def _get_last_by_position(self, definitions: List[EnvVariable]) -> EnvVariable:
        """Get the definition with the latest position (last in dependency order)."""
        return max(definitions, key=lambda d: d.position)

