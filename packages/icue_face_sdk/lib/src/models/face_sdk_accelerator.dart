enum FaceSdkAccelerator {
  cpu('cpu'),
  gpu('gpu'),
  npu('npu');

  const FaceSdkAccelerator(this.nativeValue);

  final String nativeValue;
}
