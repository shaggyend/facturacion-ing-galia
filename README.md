# Facturación y Presupuestos — Ingeniería Galia, c.a.

Aplicación multiplataforma en **Flutter** (Web, Escritorio y Móvil) para emitir presupuestos y facturas de **Ingenieria Galia, c.a.** replicando exactamente el formato institucional en PDF tamaño Carta (`US Letter`).

## Estructura del proyecto

- `lib/core/company_constants.dart`: Datos institucionales fijos, colores y medidas del documento.
- `lib/core/formatters.dart`: Formateo de fecha (`Caracas, DD de Mes del AAAA`), parseo numérico flexible y separación entero/decimales.
- `lib/models/budget_document.dart`: Modelos inmutables (`BudgetDocument`, `BudgetItem`, moneda `€`/`$`, Modos A y B).
- `lib/services/pdf_generator.dart`: Generador PDF (`pdf`) con fuentes embebidas (`Tinos` y `Arimo`), logo "I G", recuadro redondeado `Sr. (es):`, tabla de 4 columnas con división decimal y soporte multipágina.
- `lib/widgets/document_preview.dart`: Vista previa en vivo idéntica al PDF con zoom interactivo.
- `lib/widgets/budget_form.dart`: Formulario responsivo con Modo A (descripción + monto directo), Modo B (ítems con cálculo automático) y selector de logo personalizado.
- `lib/screens/budget_home_screen.dart`: Interfaz adaptativa (panel dividido en escritorio / pestañas en móvil).
- `lib/screens/pdf_preview_screen.dart`: Visor PDF nativo (`printing`) para imprimir, descargar o compartir.
- `assets/images/logo_ig.png`: Logo "I G" editable/reemplazable.

## Cómo ejecutarla

### 1. En Web (Chrome / Edge — disponible de inmediato)
```bash
flutter run -d chrome
```
O compilar para producción web:
```bash
flutter build web
```

### 2. En Teléfono Android
1. Actualiza Android SDK 36 y acepta licencias (`flutter doctor --android-licenses`).
2. Conecta tu teléfono con depuración USB activada (o abre un emulador) y ejecuta:
```bash
flutter run
```
Para generar el APK instalable:
```bash
flutter build apk --release
```

### 3. En Escritorio Windows nativo
Requiere **Visual Studio** con la carga de trabajo *"Desarrollo para el escritorio con C++"* y **Modo de desarrollador** activo en Windows (`start ms-settings:developers`):
```bash
flutter run -d windows
```
