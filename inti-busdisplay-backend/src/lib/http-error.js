// Pesan di sini dikirim ke aplikasi sebagai { error }, jadi harus pendek, berbahasa
// Indonesia, dan aman ditampilkan ke operator (ApiService menyaring pesan > 200 karakter).
class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

module.exports = { HttpError };
