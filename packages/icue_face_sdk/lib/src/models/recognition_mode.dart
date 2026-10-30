enum RecognitionMode {
  single('SINGLE'),
  multi('MULTI');

  const RecognitionMode(this.nativeValue);

  final String nativeValue;
}
