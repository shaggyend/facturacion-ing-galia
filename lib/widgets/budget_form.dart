import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'package:facturacion_ing_galia/core/company_constants.dart';
import 'package:facturacion_ing_galia/core/formatters.dart';
import 'package:facturacion_ing_galia/models/budget_document.dart';

class _ItemFieldControllers {
  _ItemFieldControllers({
    required String quantityText,
    required String descriptionText,
    required String unitPriceText,
  })  : quantity = TextEditingController(text: quantityText),
        description = TextEditingController(text: descriptionText),
        unitPrice = TextEditingController(text: unitPriceText);

  final TextEditingController quantity;
  final TextEditingController description;
  final TextEditingController unitPrice;

  void dispose() {
    quantity.dispose();
    description.dispose();
    unitPrice.dispose();
  }
}

/// Interactive form for editing all budget/invoice fields and switching modes.
class BudgetForm extends StatefulWidget {
  const BudgetForm({
    super.key,
    required this.document,
    required this.syncVersion,
    required this.onChanged,
  });

  final BudgetDocument document;
  final int syncVersion;
  final ValueChanged<BudgetDocument> onChanged;

  @override
  State<BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<BudgetForm> {
  late final TextEditingController _recipientCtrl;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _numberCtrl;
  late final TextEditingController _workTitleCtrl;
  late final TextEditingController _workDetailsCtrl;
  late final TextEditingController _manualTotalCtrl;
  late final TextEditingController _paymentTermsCtrl;
  late final TextEditingController _executionTimeCtrl;

  final Map<String, _ItemFieldControllers> _itemCtrls =
      <String, _ItemFieldControllers>{};

  int _nextItemSeed = 100;

  @override
  void initState() {
    super.initState();
    final doc = widget.document;
    _recipientCtrl = TextEditingController(text: doc.recipient);
    _dateCtrl = TextEditingController(text: doc.dateText);
    _numberCtrl = TextEditingController(text: doc.documentNumber);
    _workTitleCtrl = TextEditingController(text: doc.workTitle);
    _workDetailsCtrl = TextEditingController(text: doc.workDetails);
    _manualTotalCtrl = TextEditingController(
      text: _formatEditableAmount(doc.manualTotal),
    );
    _paymentTermsCtrl = TextEditingController(text: doc.paymentTerms);
    _executionTimeCtrl = TextEditingController(text: doc.executionTime);
    _syncItemControllers(doc.items, forceReset: true);
  }

  @override
  void didUpdateWidget(covariant BudgetForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.syncVersion != oldWidget.syncVersion) {
      final doc = widget.document;
      _recipientCtrl.text = doc.recipient;
      _dateCtrl.text = doc.dateText;
      _numberCtrl.text = doc.documentNumber;
      _workTitleCtrl.text = doc.workTitle;
      _workDetailsCtrl.text = doc.workDetails;
      _manualTotalCtrl.text = _formatEditableAmount(doc.manualTotal);
      _paymentTermsCtrl.text = doc.paymentTerms;
      _executionTimeCtrl.text = doc.executionTime;
      _syncItemControllers(doc.items, forceReset: true);
    } else if (widget.document.items != oldWidget.document.items) {
      _syncItemControllers(widget.document.items, forceReset: false);
    }
  }

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _dateCtrl.dispose();
    _numberCtrl.dispose();
    _workTitleCtrl.dispose();
    _workDetailsCtrl.dispose();
    _manualTotalCtrl.dispose();
    _paymentTermsCtrl.dispose();
    _executionTimeCtrl.dispose();
    for (final c in _itemCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncItemControllers(
    List<BudgetItem> items, {
    required bool forceReset,
  }) {
    final activeIds = items.map((e) => e.id).toSet();
    final removedIds =
        _itemCtrls.keys.where((id) => !activeIds.contains(id)).toList();
    for (final id in removedIds) {
      _itemCtrls.remove(id)?.dispose();
    }

    for (final item in items) {
      final existing = _itemCtrls[item.id];
      if (existing == null) {
        _itemCtrls[item.id] = _ItemFieldControllers(
          quantityText: DocumentFormatters.formatQuantity(item.quantity),
          descriptionText: item.description,
          unitPriceText: _formatEditableAmount(item.unitPrice),
        );
      } else if (forceReset) {
        existing.quantity.text =
            DocumentFormatters.formatQuantity(item.quantity);
        existing.description.text = item.description;
        existing.unitPrice.text = _formatEditableAmount(item.unitPrice);
      }
    }
  }

  String _formatEditableAmount(double amount) {
    if (amount <= 0) return '';
    return DocumentFormatters.splitCurrencyAmount(amount).formattedWithComma;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      helpText: 'Seleccionar fecha del documento',
    );
    if (picked == null) return;
    final formatted = DocumentFormatters.formatCaracasDate(picked);
    _dateCtrl.text = formatted;
    widget.onChanged(widget.document.copyWith(dateText: formatted));
  }

  Future<void> _pickCustomLogo() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Seleccionar logo de la empresa',
      type: FileType.custom,
      allowedExtensions: const <String>['png', 'jpg', 'jpeg', 'webp'],
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty || !mounted) return;
    widget.onChanged(widget.document.copyWith(customLogoBytes: bytes));
  }

  void _addItem() {
    _nextItemSeed++;
    final newItem = BudgetItem(
      id: 'item-${DateTime.now().microsecondsSinceEpoch}-$_nextItemSeed',
      quantity: 1,
      description: '',
      unitPrice: 0,
    );
    final updated = List<BudgetItem>.from(widget.document.items)..add(newItem);
    widget.onChanged(widget.document.copyWith(items: updated));
  }

  void _updateItem(int index, BudgetItem updatedItem) {
    final updated = List<BudgetItem>.from(widget.document.items);
    updated[index] = updatedItem;
    widget.onChanged(widget.document.copyWith(items: updated));
  }

  void _removeItem(int index) {
    if (widget.document.items.length <= 1) {
      const empty = BudgetItem(
        id: 'item-reset',
        quantity: 1,
        description: '',
        unitPrice: 0,
      );
      widget.onChanged(widget.document.copyWith(items: const [empty]));
      _syncItemControllers(const [empty], forceReset: true);
      return;
    }
    final updated = List<BudgetItem>.from(widget.document.items)
      ..removeAt(index);
    widget.onChanged(widget.document.copyWith(items: updated));
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final splitTotal = DocumentFormatters.splitCurrencyAmount(doc.effectiveTotal);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _FormSectionCard(
          title: 'Datos del Documento',
          icon: Icons.description_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<DocumentTypeLabel>(
                      segments: const [
                        ButtonSegment(
                          value: DocumentTypeLabel.presupuesto,
                          label: Text('Presupuesto'),
                        ),
                        ButtonSegment(
                          value: DocumentTypeLabel.factura,
                          label: Text('Factura'),
                        ),
                      ],
                      selected: {doc.documentType},
                      onSelectionChanged: (sel) {
                        widget.onChanged(
                          doc.copyWith(documentType: sel.first),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _numberCtrl,
                      decoration: InputDecoration(
                        labelText: doc.documentType.documentTitle,
                        hintText: 'Ej: 2026-0094',
                        prefixIcon: const Icon(Icons.tag),
                      ),
                      onChanged: (value) {
                        widget.onChanged(doc.copyWith(documentNumber: value));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Moneda',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CurrencyOption>(
                          isExpanded: true,
                          isDense: true,
                          value: doc.currency,
                          items: CurrencyOption.values
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.label),
                                ),
                              )
                              .toList(),
                          onChanged: (selected) {
                            if (selected != null) {
                              widget.onChanged(
                                doc.copyWith(currency: selected),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateCtrl,
                decoration: InputDecoration(
                  labelText: 'Fecha',
                  hintText: 'Caracas, DD de Mes del AAAA',
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'Elegir fecha en calendario',
                    onPressed: _pickDate,
                    icon: const Icon(Icons.edit_calendar_outlined),
                  ),
                ),
                onChanged: (value) {
                  widget.onChanged(doc.copyWith(dateText: value));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _FormSectionCard(
          title: 'Destinatario (Sr. (es):)',
          icon: Icons.business_outlined,
          child: TextFormField(
            controller: _recipientCtrl,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText:
                  'JUNTA DE CONDOMINIO\nRES. ORLANDO\nURB. LA CANDELARIA\nPRESENTE.-',
              alignLabelWithHint: true,
            ),
            onChanged: (value) {
              widget.onChanged(doc.copyWith(recipient: value));
            },
          ),
        ),
        const SizedBox(height: 14),
        _FormSectionCard(
          title: 'Trabajo y Montos',
          icon: Icons.engineering_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<WorkEntryMode>(
                segments: const [
                  ButtonSegment(
                    value: WorkEntryMode.directTotal,
                    icon: Icon(Icons.notes_outlined),
                    label: Text('Modo A: Directo'),
                  ),
                  ButtonSegment(
                    value: WorkEntryMode.itemized,
                    icon: Icon(Icons.list_alt_outlined),
                    label: Text('Modo B: Por ítems'),
                  ),
                ],
                selected: {doc.mode},
                onSelectionChanged: (sel) {
                  widget.onChanged(doc.copyWith(mode: sel.first));
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _workTitleCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: doc.mode == WorkEntryMode.directTotal
                      ? 'Título del trabajo'
                      : 'Título general (opcional)',
                  hintText: 'Ej: TRABAJO EN BOMBA DE AGUA',
                ),
                onChanged: (value) {
                  widget.onChanged(doc.copyWith(workTitle: value));
                },
              ),
              const SizedBox(height: 12),
              if (doc.mode == WorkEntryMode.directTotal)
                ..._buildModeAFields(doc)
              else
                ..._buildModeBFields(doc),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: CompanyConstants.headerBlueColor
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'TOTAL CALCULADO',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: CompanyConstants.headerBlueColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${doc.currency.symbol} ${splitTotal.formattedWithComma}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: CompanyConstants.headerBlueColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _FormSectionCard(
          title: 'Condiciones Comerciales',
          icon: Icons.handshake_outlined,
          child: Column(
            children: [
              TextFormField(
                controller: _paymentTermsCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Forma de Pago',
                  hintText: '70% al aprobar\n30% al finalizar',
                ),
                onChanged: (value) {
                  widget.onChanged(doc.copyWith(paymentTerms: value));
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _executionTimeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tiempo de Ejecución',
                  hintText: '5 dias habiles',
                ),
                onChanged: (value) {
                  widget.onChanged(doc.copyWith(executionTime: value));
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Nota fija en plantilla: "${CompanyConstants.taxNote}"',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _FormSectionCard(
          title: 'Logo "I G" de la Empresa',
          icon: Icons.image_outlined,
          child: _LogoCustomizerRow(
            customLogoBytes: doc.customLogoBytes,
            onPickLogo: _pickCustomLogo,
            onResetLogo: doc.customLogoBytes == null
                ? null
                : () => widget.onChanged(doc.copyWith(clearCustomLogo: true)),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildModeAFields(BudgetDocument doc) {
    return [
      TextFormField(
        controller: _workDetailsCtrl,
        minLines: 4,
        maxLines: 12,
        decoration: const InputDecoration(
          labelText: 'Detalle de tareas realizadas',
          hintText:
              'Desarmar bomba en sitio\nRectificacion de Impulsor...\nArmar bomba en sitio',
          alignLabelWithHint: true,
        ),
        onChanged: (value) {
          widget.onChanged(doc.copyWith(workDetails: value));
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _manualTotalCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Monto Total Directo (${doc.currency.symbol})',
          hintText: 'Ej: 475,00',
          prefixText: '${doc.currency.symbol} ',
        ),
        onChanged: (value) {
          final parsed = DocumentFormatters.parseFlexibleNumber(value);
          widget.onChanged(doc.copyWith(manualTotal: parsed));
        },
      ),
    ];
  }

  List<Widget> _buildModeBFields(BudgetDocument doc) {
    return [
      for (int i = 0; i < doc.items.length; i++)
        _ItemEditorCard(
          key: ValueKey(doc.items[i].id),
          index: i,
          item: doc.items[i],
          currencySymbol: doc.currency.symbol,
          controllers: _itemCtrls[doc.items[i].id]!,
          onChanged: (updated) => _updateItem(i, updated),
          onDelete: () => _removeItem(i),
        ),
      const SizedBox(height: 4),
      OutlinedButton.icon(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Agregar ítem'),
      ),
    ];
  }
}

class _FormSectionCard extends StatelessWidget {
  const _FormSectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: CompanyConstants.headerBlueColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ItemEditorCard extends StatelessWidget {
  const _ItemEditorCard({
    super.key,
    required this.index,
    required this.item,
    required this.currencySymbol,
    required this.controllers,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final BudgetItem item;
  final String currencySymbol;
  final _ItemFieldControllers controllers;
  final ValueChanged<BudgetItem> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final splitSubtotal =
        DocumentFormatters.splitCurrencyAmount(item.subtotal);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ítem #${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  'Subtotal: $currencySymbol ${splitSubtotal.formattedWithComma}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: CompanyConstants.headerBlueColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Eliminar ítem',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controllers.description,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              hintText: 'Detalle del servicio o repuesto',
              isDense: true,
            ),
            onChanged: (val) => onChanged(item.copyWith(description: val)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: controllers.quantity,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    isDense: true,
                  ),
                  onChanged: (val) {
                    final qty = DocumentFormatters.parseFlexibleNumber(val);
                    onChanged(item.copyWith(quantity: qty));
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: controllers.unitPrice,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Precio Unitario ($currencySymbol)',
                    hintText: '0,00',
                    isDense: true,
                  ),
                  onChanged: (val) {
                    final price = DocumentFormatters.parseFlexibleNumber(val);
                    onChanged(item.copyWith(unitPrice: price));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogoCustomizerRow extends StatelessWidget {
  const _LogoCustomizerRow({
    required this.customLogoBytes,
    required this.onPickLogo,
    required this.onResetLogo,
  });

  final Uint8List? customLogoBytes;
  final VoidCallback onPickLogo;
  final VoidCallback? onResetLogo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 54,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: customLogoBytes != null
              ? Image.memory(customLogoBytes!, fit: BoxFit.contain)
              : Image.asset(
                  CompanyConstants.defaultLogoAsset,
                  fit: BoxFit.contain,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onPickLogo,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Cambiar logo'),
              ),
              if (onResetLogo != null)
                TextButton(
                  onPressed: onResetLogo,
                  child: const Text('Restaurar "I G"'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
