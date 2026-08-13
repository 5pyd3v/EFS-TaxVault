sealed class FbrSubmitOutcome {
  const FbrSubmitOutcome();
}

class FbrSubmitAccepted extends FbrSubmitOutcome {
  const FbrSubmitAccepted(this.externalReference);
  final String externalReference;
}

class FbrSubmitAlreadySubmitted extends FbrSubmitOutcome {
  const FbrSubmitAlreadySubmitted(this.externalReference);
  final String? externalReference;
}

class FbrSubmitValidationFailed extends FbrSubmitOutcome {
  const FbrSubmitValidationFailed(this.errors);
  final List<String> errors;
}
