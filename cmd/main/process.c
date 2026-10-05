/* Process IO boundary only. All database and codec logic lives in MoonBit. */
#include <stdio.h>
#include "moonbit.h"
MOONBIT_FFI_EXPORT void moon_dbc_stderr(moonbit_bytes_t bytes) {
  fwrite(bytes, 1, Moonbit_array_length(bytes), stderr);
  fflush(stderr);
  moonbit_decref(bytes);
}
