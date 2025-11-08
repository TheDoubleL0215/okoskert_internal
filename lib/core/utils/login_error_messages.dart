String getLoginErrorMessage(String code) {
  switch (code) {
    case 'user-not-found':
      return 'Nem található felhasználó ezzel az email címmel.';
    case 'wrong-password':
      return 'Helytelen jelszó.';
    case 'invalid-email':
      return 'Érvénytelen email cím.';
    case 'user-disabled':
      return 'Ez a felhasználói fiók le van tiltva.';
    case 'too-many-requests':
      return 'Túl sok sikertelen próbálkozás. Kérjük, próbáld később.';
    case 'network-request-failed':
      return 'Hálózati hiba. Kérjük, ellenőrizd az internetkapcsolatod.';
    default:
      return 'Bejelentkezési hiba: $code';
  }
}
