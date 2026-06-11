import 'block_types.dart';
import 'campaign_assembler.dart';
import 'fallback_blocks.dart';

class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final CampaignOutput? fixedOutput;

  const ValidationResult({
    required this.isValid,
    required this.errors,
    this.fixedOutput,
  });
}

class ValidationEngine {
  static final RegExp _placeholderRegex = RegExp(r'\{[a-zA-Z_]+\}');

  static ValidationResult validate(CampaignOutput output, CampaignInput input) {
    final List<String> errors = [];
    bool needsFix = false;

    CampaignBlock hook = output.hookBlock;
    CampaignBlock value = output.valueBlock;
    CampaignBlock proof = output.proofBlock;
    CampaignBlock cta = output.ctaBlock;

    // 1. Verify existence of blocks
    if (hook.template.trim().isEmpty) {
      errors.add('Hook block is empty');
      hook = FallbackBlocks.hook;
      needsFix = true;
    }
    if (value.template.trim().isEmpty) {
      errors.add('Value block is empty');
      value = FallbackBlocks.value;
      needsFix = true;
    }
    if (proof.template.trim().isEmpty) {
      errors.add('Proof block is empty');
      proof = FallbackBlocks.proof;
      needsFix = true;
    }
    if (cta.template.trim().isEmpty) {
      errors.add('CTA block is empty');
      cta = FallbackBlocks.cta;
      needsFix = true;
    }

    // 2. Re-assemble text if block substitution happened
    String assembledText = output.assembledText;
    if (needsFix) {
      assembledText = '${hook.template}\n\n${value.template}\n\n${proof.template}\n\n${cta.template}';
      assembledText = CampaignAssembler.replacePlaceholders(assembledText, input);
    }

    // 3. Check for unresolved placeholders
    if (_placeholderRegex.hasMatch(assembledText)) {
      errors.add('Unresolved placeholders found in assembled text');
      // Clean up unresolved placeholders by stripping them
      assembledText = assembledText.replaceAll(_placeholderRegex, '').replaceAll(RegExp(r'\s+'), ' ').trim();
      needsFix = true;
    }

    // 4. Verify output length is not completely empty
    if (assembledText.trim().isEmpty) {
      return const ValidationResult(
        isValid: false,
        errors: ['Assembled campaign text is empty'],
      );
    }

    if (errors.isEmpty) {
      return const ValidationResult(isValid: true, errors: []);
    }

    return ValidationResult(
      isValid: false,
      errors: errors,
      fixedOutput: CampaignOutput(
        hookBlock: hook,
        valueBlock: value,
        proofBlock: proof,
        ctaBlock: cta,
        assembledText: assembledText,
        metadata: {
          ...output.metadata,
          'validation_auto_fixed': 'true',
          'validation_errors_fixed': errors.join(', '),
        },
      ),
    );
  }
}
