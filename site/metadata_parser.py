import os
import argparse
from debian import deb822
from validators import parse_validator
from env_types import EnvVariable, EnvLayer, MetadataContainer, XEnv
from logger import log_error


class ValidationResultBuilder:
    """Build a validation result dictionary."""

    def __init__(self, filepath: str = ""):
        self.filepath = filepath

    def build_result(self, status: str, value=None, valid=None, required=False, **kwargs):
        """Build a standardised validation result dictionary."""
        result = {
            "status": status,
            "value": value,
            "valid": valid,
            "required": required
        }

        # Add any additional fields passed in kwargs
        result.update(kwargs)
        return result

    def missing_var_prefix(self):
        """Build result for missing variable prefix error."""
        return self.build_result(
            status="missing_var_prefix",
            valid=False,
            required=True,
            message=f"{XEnv.VAR_PREFIX}* fields are defined but {XEnv.var_prefix()} is missing. Environment variables require a valid prefix."
        )

    def orphaned_attributes(self, varname: str):
        """Build result for orphaned variable attributes."""
        return self.build_result(
            status="orphaned_attributes",
            valid=False,
            required=False,
            message=f"{self.filepath}: Found attribute fields for variable '{varname}' but no base {XEnv.var_base(varname)} definition"
        )

    def unsupported_validation_rule(self, var_name: str, rule: str, value=None, required=False):
        """Build result for unsupported validation rule."""
        return self.build_result(
            status="unsupported_field",
            value=value,
            valid=False,
            required=required,
            message=f"{self.filepath}: Unsupported validation rule '{rule}' for variable {var_name}"
        )

    def variable_validated(self, value, is_valid: bool, required: bool, rule: str, errors=None):
        """Build result for validated variable."""
        result = self.build_result(
            status="validated",
            value=value,
            valid=is_valid,
            required=required,
            rule=rule
        )
        if errors:
            result['errors'] = errors
        return result

    def missing_required(self):
        """Build result for missing required variable."""
        return self.build_result(
            status="missing_required",
            valid=False,
            required=True
        )

    def lazy_overridden(self, current_value, required: bool):
        """Build result for lazy variable that was overridden."""
        return self.build_result(
            status="lazy_overridden",
            value=current_value,
            valid=True,
            required=required
        )


# Central definition of supported field patterns
SUPPORTED_FIELD_PATTERNS = {
    # Variable prefix
    XEnv.var_prefix(): {"type": "single", "description": "Variable prefix for environment variables"},

    # Layer management fields
    XEnv.layer_name(): {"type": "single", "description": "Layer name identifier"},
    XEnv.layer_description(): {"type": "single", "description": "Layer description"},
    XEnv.layer_version(): {"type": "single", "description": "Layer version"},
    XEnv.layer_requires(): {"type": "single", "description": "Required layer dependencies"},
    XEnv.layer_conflicts(): {"type": "single", "description": "Conflicting layers"},
    XEnv.layer_category(): {"type": "single", "description": "Layer category"},
    XEnv.layer_provides(): {"type": "single", "description": "Capabilities provided by this layer"},
    XEnv.layer_requires_provider(): {"type": "single", "description": "Capabilities required (virtual)"},

    # Variable definition patterns (these match multiple fields)
    f"{XEnv.VAR_PREFIX}": {"type": "pattern", "description": "Environment variable definition"},
    XEnv.var_desc_pattern(): {"type": "pattern", "description": "Environment variable description"},
    XEnv.var_required_pattern(): {"type": "pattern", "description": "Whether variable is required"},
    XEnv.var_valid_pattern(): {"type": "pattern", "description": "Variable validation rule"},
    XEnv.var_set_pattern(): {"type": "pattern", "description": "Whether to auto-set variable"},

    # Variable requirements (any environment variables)
    XEnv.var_requires(): {"type": "single", "description": "Environment variables required by this layer"},
    XEnv.var_requires_valid(): {"type": "single", "description": "Validation rules for required environment variables"},
    XEnv.var_optional(): {"type": "single", "description": "Optional environment variables used by this layer"},
    XEnv.var_optional_valid(): {"type": "single", "description": "Validation rules for optional environment variables"},
}

def is_field_supported(field_name: str) -> bool:
    """Check if a field name is supported based on our defined patterns"""
    # Check exact matches first
    if field_name in SUPPORTED_FIELD_PATTERNS:
        return True

    # Check pattern matches
    for pattern, info in SUPPORTED_FIELD_PATTERNS.items():
        if info["type"] == "pattern":
            if pattern.endswith("-"):
                # Variable base pattern (X-Env-Var-)
                if field_name.startswith(pattern) and '-' not in field_name[len(pattern):]:
                    return True
            elif "*" in pattern:
                # Variable attribute pattern (X-Env-Var-*-Desc)
                pattern_parts = pattern.split("*")
                if len(pattern_parts) == 2:
                    prefix, suffix = pattern_parts
                    if field_name.startswith(prefix) and field_name.endswith(suffix):
                        # Extract the variable name part
                        var_part = field_name[len(prefix):-len(suffix) if suffix else len(field_name)]
                        if var_part and '-' not in var_part:  # Valid variable name
                            return True

    return False

def get_supported_fields_list() -> list:
    """Get a formatted list of supported fields for display"""
    fields = []
    for field, info in SUPPORTED_FIELD_PATTERNS.items():
        if info["type"] == "single":
            fields.append(field)
        elif info["type"] == "pattern":
            fields.append(field.replace("*", "*"))  # Keep the * for display
    return sorted(fields)

class Metadata:
    """Metadata parser with modular classes."""

    def __init__(self, filepath):
        self.filepath = filepath
        raw_metadata = self._load_metadata(filepath)

        # Create the container (applies placeholder substitutions internally)
        self._container = MetadataContainer.from_metadata_dict(raw_metadata, filepath)

        # Create validation result builder
        self._result_builder = ValidationResultBuilder(filepath)

    def _validate_deb822_format(self, meta_lines):
        """
        Validate that metadata lines follow proper DEB822 format.
        Python deb822 is very forgiving and tries hard to avoid parsing errors
        however this is at the detriment of silent data omissions, eg line
        continuation problems. Try to mitigate such problems here.
        """
        if not meta_lines:
            return

        # Check line contination syntax
        for i, line in enumerate(meta_lines):
            # Check for invalid continuation lines
            if (':' not in line and  # Not a field definition
                not line.startswith(' ') and  # Not indented with space
                not line.startswith('\t') and  # Not indented with tab
                line.strip() and  # Not empty
                i > 0):  # Not the first line

                raise ValueError(f"Invalid DEB822 format: line '{line}' appears to be a continuation but is not indented. "
                               f"Continuation lines must start with a space or tab.")

        # Check for proper field name syntax (first line of each field)
        for line in meta_lines:
            if ':' in line and not line.startswith(' ') and not line.startswith('\t'):
                field_name = line.split(':', 1)[0].strip()
                # Basic field name validation (RFC822 style)
                if not field_name or not field_name.replace('-', '').replace('_', '').isalnum():
                    raise ValueError(f"Invalid field name '{field_name}': field names must contain only letters, numbers, hyphens, and underscores")

    def _load_metadata(self, path):
        """Load metadata from file"""
        if not os.path.isfile(path):
            raise FileNotFoundError(f"Metadata source not found: {path}")

        with open(path, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        # Extract metadata block if embedded
        if any(line.strip() == '# METABEGIN' for line in lines):
            # Find METABEGIN and METAEND markers in comment blocks
            in_meta = False
            meta_lines = []

            for line in lines:
                stripped = line.strip()
                if stripped == '# METABEGIN':
                    in_meta = True
                    continue
                elif stripped == '# METAEND':
                    break
                elif in_meta:
                    # Extract everything between them (remove '# ' from each line)
                    if line.startswith('# '):
                        clean_line = line[2:].rstrip()
                        # Remove empty lines
                        if clean_line.strip():
                            meta_lines.append(clean_line)
                    elif line.startswith('#'):
                        # Handle lines with just '#' (no space)
                        clean_line = line[1:].rstrip()
                        if clean_line.strip():
                            meta_lines.append(clean_line)

            # Validate before parsing
            self._validate_deb822_format(meta_lines)
            meta_str = "\n".join(meta_lines)
        else:
            # Handle files with direct X-Env-* fields (no comment wrapper)
            meta_lines = []
            for line in lines:
                line = line.rstrip()
                # Only keep non-comment, non-empty lines that look like metadata
                if line and not line.startswith('#') and ':' in line:
                    field_name = line.split(':', 1)[0].strip()
                    if field_name.startswith('X-Env-'):
                        meta_lines.append(line)

            # Validate before parsing
            self._validate_deb822_format(meta_lines)
            meta_str = "\n".join(meta_lines)

        # Throw directly at deb822 module
        try:
            result = deb822.Deb822(meta_str)

            # Minimal post-processing: validate field names and check for empty metadata
            if result:
                # Check all fields are X-Env-
                invalid_fields = [field for field in result.keys() if not field.startswith('X-Env-')]
                if invalid_fields:
                    raise ValueError(f"Invalid field names (must start with 'X-Env-'): {', '.join(invalid_fields)}")
            elif meta_str.strip():
                # File has data but not X-Env
                raise ValueError(f"No valid X-Env-* fields found in metadata")
            # Otherwise it's intentionally empty

            return result
        except Exception as e:
            raise ValueError(f"Failed to parse metadata in {path}: {e}")

    def get_metadata(self):
        """Get raw metadata dictionary."""
        return self._container.raw_metadata

    def get_unset_env_vars(self):
        """Get environment variables that are not currently set in the environment"""
        return self._get_env_vars_internal(only_unset=True)

    def get_all_env_vars(self):
        """Get all environment variables defined in metadata, regardless of whether they're set in environment"""
        return self._get_env_vars_internal(only_unset=False)


    def _get_env_vars_internal(self, only_unset=True):
        """Internal method to get environment variables with optional filtering"""
        result = {}

        # Check for unsupported fields first
        unsupported_fields = self._check_unsupported_fields()
        if unsupported_fields:
            raise ValueError(f"Cannot process variables with unsupported fields: {list(unsupported_fields.keys())}. Run 'validate' command for details.")

        # Check if variables are defined but no prefix is provided
        if self._container.variables and not self._container.var_prefix:
            raise ValueError("Cannot process variables: X-Env-Var-* fields are defined but X-Env-VarPrefix is missing. Environment variables require a valid prefix.")

        for var_name, env_var in self._container.variables.items():
            # Apply filtering based on only_unset parameter
            if only_unset:
                if var_name not in os.environ:
                    result[var_name] = env_var.value
            else:
                result[var_name] = env_var.value

        return result

    def get_variable_description(self, varname):
        """Get variable description information."""
        # Try multiple lookup strategies
        env_var_obj = None
        full_var_name = None

        # 1. Exact match first
        if varname in self._container.variables:
            full_var_name = varname
            env_var_obj = self._container.variables[varname]
        else:
            # 2. Look for variables ending with the requested name
            for var_name, env_var in self._container.variables.items():
                if var_name.endswith(f"_{varname.lower()}") or var_name.lower().endswith(f"_{varname.lower()}"):
                    full_var_name = var_name
                    env_var_obj = env_var
                    break

        if env_var_obj is None:
            # Variable not found
            raise ValueError(f"Variable '{varname}' not found in metadata")

        return {
            "name": full_var_name,
            "description": env_var_obj.description,
            "valid": env_var_obj.get_validation_description(),
            "set": env_var_obj.set_policy,
            "value": env_var_obj.value
        }

    def _parse_boolean(self, value, default=False):
        """Parse a boolean value from string using same logic as bool validation"""
        if not value:
            return default
        return str(value).lower() in ["true", "1", "yes", "y", "lazy", "force"]

    def _is_supported_set_policy(self, value) -> bool:
        if value is None:
            return True
        val = str(value).strip().lower()
        return val in ["false", "0", "no", "n", "true", "1", "yes", "y", "lazy", "force", "immediate"]

    def _is_valid(self, value, rule):
        """Validate a value using the new validator system"""
        try:
            validator = parse_validator(rule)
            errors = validator.validate(value)
            return len(errors) == 0
        except Exception:
            return False

    def _is_supported_rule(self, rule: str) -> bool:
        """Return True if the validation rule is recognised/supported"""
        if not rule:
            return False
        try:
            parse_validator(rule)
            return True
        except Exception:
            return False

    def _check_unsupported_fields(self):
        """Check for unsupported field names and return error messages"""
        unsupported_fields = {}

        # Only validate X-Env-Var-* fields; layer fields are handled elsewhere
        for field_name in self._container.raw_metadata.keys():
            if XEnv.is_var_field(field_name) and not is_field_supported(field_name):
                unsupported_fields[field_name] = f"'{field_name}' is not supported"
        return unsupported_fields

    def _check_unsupported_layer_fields(self):
        """Check for unsupported X-Env-Layer-* field names"""
        unsupported_fields = {}
        for field_name in self._container.raw_metadata.keys():
            if XEnv.is_layer_field(field_name) and not is_field_supported(field_name):
                unsupported_fields[field_name] = f"'{field_name}' is not supported"
        return unsupported_fields

    def validate_env_vars(self):
        """Validate environment variables - now broken into focused smaller methods"""
        # Schema validation first
        schema_errors = self._validate_schema()
        if schema_errors:
            return schema_errors

        results = {}

        # Check prefix and orphaned attributes
        prefix_errors = self._validate_prefix_and_orphans()
        if prefix_errors:
            return prefix_errors

        # Validate defined variables
        results.update(self._validate_defined_variables())

        # Validate required/optional variables
        results.update(self._validate_required_variables())
        results.update(self._validate_optional_variables())

        # Check layer-level unsupported fields
        results.update(self._validate_layer_fields())

        return results

    def _validate_schema(self):
        """Validate schema and return errors if any."""
        return self._collect_schema_errors()

    def _validate_prefix_and_orphans(self):
        """Check for missing prefix and orphaned variable attributes."""
        results = {}

        # Check if variables are defined but no prefix is provided
        if self._container.variables and not self._container.var_prefix:
            results["MISSING_VAR_PREFIX"] = self._result_builder.missing_var_prefix()
            return results

        # Check for orphaned variable attribute fields
        base_vars = set()
        attribute_vars = set()

        for key in self._container.raw_metadata.keys():
            if XEnv.is_var_field(key) and is_field_supported(key):
                if XEnv.is_base_var_field(key):
                    # Base variable definition
                    base_vars.add(XEnv.extract_base_var_name(key).lower())
                elif any(key.endswith(suffix) for suffix in ["-Desc", "-Valid", "-Required", "-Set"]):
                    # Attribute field - extract variable name
                    var_part = XEnv.extract_var_name(key)
                    for suffix in ["-Desc", "-Valid", "-Required", "-Set"]:
                        if var_part.endswith(suffix):
                            varname = var_part[:-len(suffix)].lower()
                            attribute_vars.add(varname)
                            break

        orphaned_vars = attribute_vars - base_vars
        for varname in orphaned_vars:
            results[f"ORPHANED_ATTRS_{varname.upper()}"] = self._result_builder.orphaned_attributes(varname)

        return results

    def _validate_defined_variables(self):
        """Validate all defined variables from the metadata."""
        results = {}

        for var_name, env_var in self._container.variables.items():
            current_value = os.environ.get(var_name)

            # First check for unsupported validation rules - this should always be checked
            var_short_name = var_name.split('_')[-1].upper()
            valid_rule_str = self._container.raw_metadata.get(XEnv.var_valid(var_short_name))
            if valid_rule_str and not self._is_supported_rule(valid_rule_str):
                # Unsupported validation rule trumps everything else
                results[f"DEFAULT_{var_name}"] = self._result_builder.unsupported_validation_rule(
                    var_name, valid_rule_str, env_var.value, env_var.required
                )
                continue

            # Check if this variable was lazy and did not win
            if env_var.set_policy == "lazy" and current_value is not None and current_value != env_var.value:
                results[var_name] = self._result_builder.lazy_overridden(current_value, env_var.required)
                continue

            # Validate default value if validator exists and can be set
            if env_var.validator and env_var.should_set_in_environment():
                validation_errors = env_var.validate_value()
                if validation_errors:
                    results[f"DEFAULT_{var_name}"] = self._result_builder.build_result(
                        status="invalid_default",
                        value=env_var.value,
                        valid=False,
                        required=env_var.required,
                        rule=env_var.get_validation_description(),
                        message=f"Default value '{env_var.value}' for {var_name} doesn't match validation rule '{env_var.get_validation_description()}'"
                    )

            # Check if required variable is missing
            if env_var.required and current_value is None:
                results[var_name] = self._result_builder.missing_required()
            elif current_value is not None:
                # Variable is set - validate it
                if env_var.validator:
                    validation_errors = env_var.validate_value(current_value)
                    is_valid = len(validation_errors) == 0
                    results[var_name] = self._result_builder.variable_validated(
                        current_value, is_valid, env_var.required, env_var.get_validation_description(),
                        validation_errors if not is_valid else None
                    )
                else:
                    results[var_name] = self._result_builder.build_result(
                        status="no_validation",
                        value=current_value,
                        valid=None,
                        required=env_var.required
                    )
            else:
                # Variable not set and not required
                results[var_name] = self._result_builder.build_result(
                    status="optional_unset",
                    value=None,
                    valid=None,
                    required=False
                )

        return results

    def _validate_required_variables(self):
        """Validate required environment variables (X-Env-VarRequires)."""
        results = {}

        if self._container.required_vars:
            required_valid_rules = self._container.raw_metadata.get(XEnv.var_requires_valid(), "")
            valid_rules = [r.strip() for r in required_valid_rules.split(',') if r.strip()] if required_valid_rules.strip() else []

            for i, req_var in enumerate(self._container.required_vars):
                current_value = os.environ.get(req_var)
                valid_rule = valid_rules[i] if i < len(valid_rules) else None

                if current_value is None:
                    results[f"REQUIRED_{req_var}"] = self._result_builder.build_result(
                        status="missing_required_var",
                        valid=False,
                        required=True,
                        required_var=req_var
                    )
                else:
                    # Required variable is set - validate it if rule provided
                    if valid_rule and not self._is_supported_rule(valid_rule):
                        results[f"REQUIRED_{req_var}"] = self._result_builder.unsupported_validation_rule(
                            req_var, valid_rule, current_value, True
                        )
                    elif valid_rule:
                        validation_errors = []
                        is_valid = True
                        try:
                            validator = parse_validator(valid_rule)
                            validation_errors = validator.validate(current_value)
                            is_valid = len(validation_errors) == 0
                        except:
                            is_valid = False

                        result = self._result_builder.build_result(
                            status="required_validated",
                            value=current_value,
                            valid=is_valid,
                            required=True,
                            rule=valid_rule,
                            required_var=req_var
                        )
                        if not is_valid and validation_errors:
                            result['errors'] = validation_errors
                        results[f"REQUIRED_{req_var}"] = result
                    else:
                        results[f"REQUIRED_{req_var}"] = self._result_builder.build_result(
                            status="required_no_validation",
                            value=current_value,
                            valid=None,
                            required=True,
                            required_var=req_var
                        )

        return results

    def _validate_optional_variables(self):
        """Validate optional environment variables (X-Env-VarOptional)."""
        results = {}

        if self._container.optional_vars:
            optional_valid_rules = self._container.raw_metadata.get(XEnv.var_optional_valid(), "")
            valid_rules = [r.strip() for r in optional_valid_rules.split(',') if r.strip()] if optional_valid_rules.strip() else []

            for i, opt_var in enumerate(self._container.optional_vars):
                current_value = os.environ.get(opt_var)
                valid_rule = valid_rules[i] if i < len(valid_rules) else None

                if current_value is None:
                    results[f"OPTIONAL_{opt_var}"] = self._result_builder.build_result(
                        status="optional_var_unset",
                        valid=None,
                        required=False,
                        optional_var=opt_var
                    )
                else:
                    # Optional variable is set - validate it if rule provided
                    if valid_rule and not self._is_supported_rule(valid_rule):
                        results[f"OPTIONAL_{opt_var}"] = self._result_builder.unsupported_validation_rule(
                            opt_var, valid_rule, current_value, False
                        )
                    elif valid_rule:
                        is_valid = self._is_valid(current_value, valid_rule)
                        results[f"OPTIONAL_{opt_var}"] = self._result_builder.build_result(
                            status="optional_validated",
                            value=current_value,
                            valid=is_valid,
                            required=False,
                            rule=valid_rule,
                            optional_var=opt_var
                        )
                    else:
                        results[f"OPTIONAL_{opt_var}"] = self._result_builder.build_result(
                            status="optional_no_validation",
                            value=current_value,
                            valid=None,
                            required=False,
                            optional_var=opt_var
                        )

        return results

    def _validate_layer_fields(self):
        """Validate layer-level fields for unsupported entries."""
        results = {}

        unsupported_layer_fields = self._check_unsupported_layer_fields()
        if unsupported_layer_fields:
            for field_name, message in unsupported_layer_fields.items():
                results[f"UNSUPPORTED_LAYER_FIELD_{field_name}"] = self._result_builder.build_result(
                    status="unsupported_field",
                    value=self._container.raw_metadata.get(field_name),
                    valid=False,
                    required=False,
                    message=message
                )

        return results

    def lint_metadata_syntax(self):
        """Lint metadata for syntax errors by filtering validation results that don't require environment variables."""
        # Reuse existing validation infrastructure
        all_results = self.validate_env_vars()

        # Filter to only syntax-related errors (don't require environment variables)
        lint_statuses = {
            "unsupported_field", "missing_var_prefix", "orphaned_attributes",
            "invalid_default", "invalid_validation_rule"
        }

        return {key: result for key, result in all_results.items()
                if result.get("status") in lint_statuses}

    def _collect_schema_errors(self):
        """Return dict {key: info_dict} for unsupported fields / invalid defaults."""
        results = {}
        # Unsupported layer / env-var fields
        unsupported_layer = self._check_unsupported_layer_fields()
        unsupported_var   = self._check_unsupported_fields()
        for fld, msg in {**unsupported_layer, **unsupported_var}.items():
            results[f"UNSUPPORTED_FIELD_{fld}"] = {
                "status": "unsupported_field",
                "value": self._container.raw_metadata.get(fld),
                "valid": False,
                "required": False,
                "message": msg,
            }
        return results

    def set_env_vars(self):
        """Set environment variables from metadata defaults using new classes"""
        results = {}

        # Check for unsupported fields first
        unsupported_fields = self._check_unsupported_fields()
        if unsupported_fields:
            raise ValueError(f"Cannot process variables with unsupported fields: {list(unsupported_fields.keys())}. Run 'validate' command for details.")

        # Check if variables are defined but no prefix is provided
        if self._container.variables and not self._container.var_prefix:
            raise ValueError("Cannot process variables: X-Env-Var-* fields are defined but X-Env-VarPrefix is missing. Environment variables require a valid prefix.")

        for var_name, env_var in self._container.variables.items():
            current_value = os.environ.get(var_name)

            if env_var.set_policy == "skip":
                results[var_name] = {
                    "status": "no_set_policy",
                    "value": None,
                    "reason": "marked as Set: false/skip"
                }
            elif env_var.set_policy == "force":
                # Always overwrite, but skip if empty and rule allows unset
                if env_var.validator and hasattr(env_var.validator, 'allow_unset') and env_var.validator.allow_unset and not env_var.value.strip():
                    results[var_name] = {
                        "status": "no_set_policy",
                        "value": None,
                        "reason": "empty value with string-or-unset validation"
                    }
                else:
                    os.environ[var_name] = env_var.value
                    results[var_name] = {
                        "status": "force_set",
                        "value": env_var.value,
                        "reason": "Set: force override"
                    }
            elif env_var.set_policy == "immediate":
                if current_value is None:
                    os.environ[var_name] = env_var.value
                    results[var_name] = {
                        "status": "set",
                        "value": env_var.value,
                        "reason": "auto-set from metadata (immediate)"
                    }
                else:
                    results[var_name] = {
                        "status": "already_set",
                        "value": current_value,
                        "reason": "already in environment"
                    }
            elif env_var.set_policy == "lazy":
                # For single-layer context, treat like immediate
                if current_value is None:
                    if env_var.validator and hasattr(env_var.validator, 'allow_unset') and env_var.validator.allow_unset and not env_var.value.strip():
                        results[var_name] = {
                            "status": "no_set_policy",
                            "value": None,
                            "reason": "empty value with string-or-unset validation"
                        }
                    else:
                        os.environ[var_name] = env_var.value
                        results[var_name] = {
                            "status": "set",
                            "value": env_var.value,
                            "reason": "auto-set from metadata (lazy, single layer)"
                        }
                else:
                    results[var_name] = {
                        "status": "already_set",
                        "value": current_value,
                        "reason": "already in environment"
                    }

        return results

    def get_layer_info(self):
        """Get layer management information from X-Env-Layer metadata fields"""
        if self._container.layer is None:
            return None
        return self._container.layer.to_dict()

    def has_layer_info(self) -> bool:
        """Check if this metadata contains X-Env-Layer information"""
        return self._container.layer is not None

    # Note: Placeholder handling moved to MetadataContainer class


def print_env_var_descriptions(meta: 'Metadata', indent: int = 0):
    """Pretty-print environment variable descriptions for a Metadata object."""
    env_vars = meta.get_all_env_vars()
    if not env_vars:
        return

    pad = " " * indent
    print(f"{pad}Environment Variables:")

    # Display the variable prefix if it exists
    if meta._container.var_prefix:
        print(f"{pad}  Variable Prefix: {meta._container.var_prefix}")
    print()

    # Fetch from the container
    for var_name, env_var in meta._container.variables.items():
        var_short_name = var_name.split('_')[-1].upper()  # Extract short name

        #print(f"{pad}  Variable: {var_short_name}")
        BOLD="\033[1m"; RESET="\033[0m"
        print(f"{pad}  Variable: {BOLD}{var_name}{RESET}")
        print(f"{pad}    Default Value: {env_var.value}")
        if env_var.description:
            print(f"{pad}    Description: {env_var.description}")
        if env_var.validator:
            rule_display = f"type:{env_var.validation_rule}" if env_var.validation_rule else "custom"
            description = env_var.get_validation_description()
            print(f"{pad}    Validation: {rule_display} [{description}]")
        print(f"{pad}    Set Policy: {env_var.set_policy}")
        print()


# Keep all the CLI and boilerplate functions from the original file
def _generate_boilerplate():
    """Generate boilerplate metadata with all supported fields and examples"""
    boilerplate = """# METABEGIN
# Layer Management Fields
# X-Env-Layer-Name: my-layer
# X-Env-Layer-Desc: Layer description
# X-Env-Layer-Version: 1.0.0
# X-Env-Layer-Category: general
#
# Dependencies (comma-separated layer names)
# X-Env-Layer-Requires:
# X-Env-Layer-Conflicts:
#
# Environment Variables
# X-Env-VarPrefix: my
#
# Variable requirements (any environment variables)
# X-Env-VarRequires: HOME,IGconf_device_user1,DOCKER_HOST
# X-Env-VarRequires-Valid: regex:^/.*,string,regex:^(unix|tcp)://.*
#
# Optional variables (validated if present, not required)
# X-Env-VarOptional: IGconf_device_user1pass,LOG_LEVEL
# X-Env-VarOptional-Valid: string,debug,info,warn,error
#
# Example variables with different validation schemes:
# X-Env-Var-hostname: localhost
# X-Env-Var-hostname-Desc: Server hostname
# X-Env-Var-hostname-Required: false
# X-Env-Var-hostname-Valid: regex:^[a-zA-Z0-9.-]+$
# X-Env-Var-hostname-Set: true
#
# X-Env-Var-port: 8080
# X-Env-Var-port-Desc: Port number (integer range)
# X-Env-Var-port-Required: false
# X-Env-Var-port-Valid: int:1024-65535
# X-Env-Var-port-Set: true
#
# X-Env-Var-environment: development
# X-Env-Var-environment-Desc: Deployment environment (enum)
# X-Env-Var-environment-Required: false
# X-Env-Var-environment-Valid: development,staging,production
# X-Env-Var-environment-Set: true
#
# X-Env-Var-debug: false
# X-Env-Var-debug-Desc: Enable debug mode (boolean)
# X-Env-Var-debug-Required: false
# X-Env-Var-debug-Valid: bool
# X-Env-Var-debug-Set: true
#
# X-Env-Var-name: myapp
# X-Env-Var-name-Desc: Application name (required non-empty string)
# X-Env-Var-name-Required: false
# X-Env-Var-name-Valid: string
# X-Env-Var-name-Set: true
#
# X-Env-Var-component: frontend
# X-Env-Var-component-Desc: Application component (alphanumeric keywords)
# X-Env-Var-component-Required: false
# X-Env-Var-component-Valid: keywords:frontend,backend,database,cache,worker
# X-Env-Var-component-Set: true
#
# Validation schemes: run 'ig metadata help-validation' for details
# METAEND"""

    print(boilerplate)

def _show_validation_help():
    """Show detailed help about validation schemes"""
    from validators import get_validation_help
    print(get_validation_help())

def Metadata_register_parser(subparsers):
    parser = subparsers.add_parser("metadata", help="Layer metadata utilities")
    parser.add_argument("--parse", metavar="PATH", help="Parse metadata from file and output environment variables")
    parser.add_argument("--validate", metavar="PATH", help="Validate metadata and environment variables")
    parser.add_argument("--describe", metavar="PATH", help="Describe layer and variable information")
    parser.add_argument("--lint", metavar="PATH", help="Lint metadata syntax and field names (no env var validation)")
    parser.add_argument("--gen", action="store_true", help="Generate boilerplate metadata template")
    parser.add_argument("--help-validation", action="store_true", help="Show validation help")
    parser.add_argument("--write-out", metavar="FILE", help="Write key=value pairs to file (works with --parse)")
    parser.set_defaults(func=_main)

def _main(args):
    if args.gen:
        _generate_boilerplate()
        return

    if args.help_validation:
        _show_validation_help()
        return

    # Determine which command is being run and get the path
    path = None
    command = None
    varname = None

    if args.parse:
        command = "parse"
        path = args.parse
    elif args.validate:
        command = "validate"
        path = args.validate
    elif args.describe:
        command = "describe"
        path = args.describe


    elif args.lint:
        command = "lint"
        path = args.lint
    else:
        print("Error: No command specified. Use -h or --help for available options.")
        exit(1)

    try:
        meta = Metadata(path)
    except Exception as e:
        print(f"Error loading metadata: {e}")
        exit(1)

    if command == "parse":
        try:
            # Early validate dependency fields for proper formatting
            _ = meta.get_layer_info()
            # First, automatically set variables with Set: true if not already set
            results = meta.set_env_vars()

            # Show SET/SKIP status for each variable
            for var, result in results.items():
                if result["status"] == "set":
                    print(f"[SET] {var}={result['value']}")
                elif result["status"] == "already_set":
                    print(f"[SKIP] {var} (already set)")
                elif result["status"] == "force_set":
                    print(f"[FORCE_SET] {var}={result['value']}")
                elif result["status"] == "no_set_policy":
                    print(f"[SKIP] {var} (Set: false/skip)")

            # Then validate that required variables are set
            validation_results = meta.validate_env_vars()
            has_validation_errors = False

            for var, result in validation_results.items():
                if result["status"] in ["missing_required", "missing_required_var"]:
                    if result["status"] == "missing_required":
                        log_error(f"Required variable {var} is not set")
                    else:
                        log_error(f"Required variable {result['required_var']} is not set")
                    has_validation_errors = True
                elif result["status"] == "validated" and not result["valid"]:
                    error_details = ""
                    if 'errors' in result and result['errors']:
                        error_details = f" - {'; '.join(result['errors'])}"
                    elif 'rule' in result:
                        error_details = f" (Expected: {result['rule']})"
                    log_error(f"Variable {var} has invalid value: {result['value']}{error_details}")
                    has_validation_errors = True
                elif result["status"] == "required_validated" and not result["valid"]:
                    error_details = ""
                    if 'errors' in result and result['errors']:
                        error_details = f" - {'; '.join(result['errors'])}"
                    elif 'rule' in result:
                        error_details = f" (Expected: {result['rule']})"
                    log_error(f"Required variable {result['required_var']} has invalid value: {result['value']}{error_details}")
                    has_validation_errors = True
                elif result["status"] == "unsupported_field":
                    log_error(result['message'])
                    has_validation_errors = True
                elif result["status"] == "missing_var_prefix":
                    log_error(result['message'])
                    has_validation_errors = True
                elif result["status"] == "invalid_default":
                    log_error(result['message'])
                    has_validation_errors = True
                elif result["status"] == "orphaned_attributes":
                    log_error(result['message'])
                    has_validation_errors = True

            if has_validation_errors:
                exit(1)

            # Write key=value pairs to file if write_out is specified
            if hasattr(args, 'write_out') and args.write_out:
                try:
                    settable_vars = {name: var.value for name, var in meta._container.get_settable_variables().items()}
                    with open(args.write_out, 'w') as f:
                        for fullvar, default_value in settable_vars.items():
                            env_value = os.environ.get(fullvar, default_value)
                            f.write(f'{fullvar}="{env_value}"\n')
                    print(f"Environment variables written to: {args.write_out}")
                except Exception as e:
                    print(f"Error writing to file {args.write_out}: {e}")
                    exit(1)
            else:
                # If no write_out specified, output to stdout (backward compatibility)
                print()
                all_vars = meta.get_all_env_vars()
                for fullvar, default_value in all_vars.items():
                    env_value = os.environ.get(fullvar, default_value)
                    print(f"{fullvar}={env_value}")
        except ValueError as e:
            print(f"Error: {e}")
            exit(1)
    elif command == "validate":
        # Trigger dependency parsing early to surface comma/format errors
        try:
            _ = meta.get_layer_info()
        except ValueError as e:
            print(f"Error: {e}")
            exit(1)

        results = meta.validate_env_vars()
        has_errors = False
        unsupported_count = 0
        for var, result in results.items():
            if result["status"] == "unsupported_field":
                print(f"[ERROR] {result['message']}")
                has_errors = True
                unsupported_count += 1
            elif result["status"] == "missing_required":
                print(f"[FAIL] {var} - REQUIRED but not set")
                has_errors = True
            elif result["status"] == "missing_required_var":
                print(f"[FAIL] {result['required_var']} - REQUIRED but not set")
                has_errors = True
            elif result["status"] == "validated":
                status = "OK" if result["valid"] else "FAIL"
                print(f"[{status}] {var}={result['value']} (rule: {result['rule']})")
                if not result["valid"]:
                    has_errors = True
            elif result["status"] == "required_validated":
                status = "OK" if result["valid"] else "FAIL"
                print(f"[{status}] {result['required_var']}={result['value']} (required, rule: {result['rule']})")
                if not result["valid"]:
                    has_errors = True
            elif result["status"] == "no_validation":
                print(f"[SKIP] {var}={result['value']} (no validation rule)")
            elif result["status"] == "required_no_validation":
                print(f"[SKIP] {result['required_var']}={result['value']} (required, no validation rule)")
            elif result["status"] == "optional_var_unset":
                print(f"[INFO] {result['optional_var']} - optional, not set")
            elif result["status"] == "optional_validated":
                status = "OK" if result["valid"] else "WARN"
                print(f"[{status}] {result['optional_var']}={result['value']} (optional, rule: {result['rule']})")
                # Note: Optional variable validation failure doesn't cause overall failure
            elif result["status"] == "optional_no_validation":
                print(f"[SKIP] {result['optional_var']}={result['value']} (optional, no validation rule)")
            elif result["status"] == "optional_unset":
                print(f"[INFO] {var} - optional, not set")
            elif result["status"] == "missing_var_prefix":
                print(f"[ERROR] {result['message']}")
                has_errors = True
            elif result["status"] == "invalid_default":
                print(f"[ERROR] {result['message']}")
                has_errors = True
            elif result["status"] == "orphaned_attributes":
                print(f"[ERROR] {result['message']}")
                has_errors = True

        # If there were unsupported fields, show all supported fields
        if unsupported_count > 0:
            print()
            print("Supported fields:")
            supported_fields = get_supported_fields_list()
            for field in supported_fields:
                print(f"  {field}")

        if has_errors:
            exit(1)

    elif command == "lint":
        lint_results = meta.lint_metadata_syntax()

        has_errors = False
        unsupported_count = 0

        for key, result in lint_results.items():
            if result["status"] == "unsupported_field":
                print(f"[ERROR] {result['message']}")
                has_errors = True
                unsupported_count += 1
            elif result["status"] in ["missing_var_prefix", "orphaned_attributes", "invalid_default"]:
                print(f"[ERROR] {result['message']}")
                has_errors = True

        # If there were unsupported fields, show all supported fields
        if unsupported_count > 0:
            print()
            print("Supported fields:")
            supported_fields = get_supported_fields_list()
            for field in supported_fields:
                print(f"  {field}")

        if has_errors:
            exit(1)
        else:
            print("OK")
    elif command == "describe":
        try:
            if not varname:
                # Show all information when no specific variable requested
                has_content = False

                # Check and display layer information
                layer_info = meta.get_layer_info()
                if layer_info:
                    print("Layer Information:")
                    print(f"  Name: {layer_info['name']}")
                    print(f"  Version: {layer_info['version']}")
                    print(f"  Category: {layer_info['category']}")

                    if layer_info['description']:
                        print(f"  Description: {layer_info['description']}")

                    deps = ', '.join(layer_info['depends']) if layer_info['depends'] else 'none'
                    print(f"  Required Dependencies: {deps}")

                    opt_deps = ', '.join(layer_info['optional_depends']) if layer_info['optional_depends'] else 'none'
                    print(f"  Optional Dependencies: {opt_deps}")

                    conflicts = ', '.join(layer_info['conflicts']) if layer_info['conflicts'] else 'none'
                    print(f"  Conflicts: {conflicts}")

                    print(f"  Filename: {layer_info['config_file']}")

                    # Show required environment variables if any
                    if meta._container.required_vars:
                        req_vars = ', '.join(meta._container.required_vars)
                        print(f"  Required Variables: {req_vars}")

                    # Show optional environment variables if any
                    if meta._container.optional_vars:
                        opt_vars = ', '.join(meta._container.optional_vars)
                        print(f"  Optional Variables: {opt_vars}")

                    print()
                    has_content = True

                # Display environment variables via helper
                if meta.get_all_env_vars():
                    print_env_var_descriptions(meta)
                    has_content = True

                if not has_content:
                    print("No layer information or environment variables defined in metadata")
            else:
                # Specific variable detail
                info = meta.get_variable_description(varname)
                print(f"Variable: {info['name']}")
                print(f"Value: {info['value']}")
                print(f"Description: {info['description']}")
                print(f"Valid Rule: {info['valid']}")
                print(f"Set Policy: {info['set']}")
        except ValueError as e:
            print(f"Error: {e}")
            exit(1)
