import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shai_hills_farm/config/app_config.dart';
import 'package:shai_hills_farm/data/receipt_reader.dart';
import 'package:shai_hills_farm/domain/receipt_draft.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/feed_mill.dart';
import 'package:shai_hills_farm/domain/farm_scope.dart';
import 'package:shai_hills_farm/domain/farm_visuals.dart';
import 'package:shai_hills_farm/domain/ids.dart';
import 'package:shai_hills_farm/domain/kpis.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/traceability.dart';
import 'package:shai_hills_farm/state/feed_controller.dart';
import 'package:shai_hills_farm/state/herd_controller.dart';
import 'package:shai_hills_farm/state/ledger_controller.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';
import 'package:shai_hills_farm/ui/card_grid.dart';
import 'package:shai_hills_farm/ui/farm_charts.dart';
import 'package:shai_hills_farm/ui/page_box.dart';
import 'package:shai_hills_farm/ui/range_menu.dart';
import 'package:shai_hills_farm/ui/status_views.dart';

/// Expenses to record, and sales to read back. Hidden from workers.
class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key, required this.ledger, this.feed, this.herd});

  final LedgerController ledger;

  /// Feed bought here is added to the store. The Feed page does not buy.
  final FeedController? feed;

  /// A livestock sale marks this animal sold.
  final HerdController? herd;

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

enum _MoneyPart { expenses, sales }

enum _LedgerFilter { all, expenses, sales }

class _MoneyScreenState extends State<MoneyScreen> {
  _MoneyPart _part = _MoneyPart.expenses;
  ExpenseCategory _category = ExpenseCategory.vet;
  Enterprise _enterprise = Enterprise.pig;
  String _feedType = feedTypes.first;
  String _vetKind = vetKinds.first;
  String _fuelType = fuelTypes.first;
  String _location = allSitesId;
  String? _error;
  bool _saving = false;
  bool _readingReceipt = false;
  bool _hasReceipt = false;
  int _photoCount = 0;
  List<_ReceiptLine> _receiptLines = [_ReceiptLine(locationId: allSitesId)];
  final _supplier = TextEditingController();

  final _amount = TextEditingController();
  final _itemName = TextEditingController();
  final _quantity = TextEditingController();
  final _saleTag = TextEditingController();
  final _saleWeight = TextEditingController();
  final _saleCost = TextEditingController();
  final _note = TextEditingController();
  final _kilos = TextEditingController();
  final _animal = TextEditingController();
  final _people = TextEditingController();
  final _days = TextEditingController();
  final _detail = TextEditingController();
  final _ledgerSearch = TextEditingController();
  _LedgerFilter _ledgerFilter = _LedgerFilter.expenses;
  ExpenseCategory? _ledgerCategory;
  ChartPreset _ledgerPreset = ChartPreset.threeMonths;
  bool _ledgerCustom = false;
  DateTime? _ledgerStart;
  DateTime? _ledgerEnd;
  String? _selectedLine;

  @override
  void dispose() {
    _amount.dispose();
    _itemName.dispose();
    _quantity.dispose();
    _saleTag.dispose();
    _saleWeight.dispose();
    _saleCost.dispose();
    _note.dispose();
    _kilos.dispose();
    _animal.dispose();
    _people.dispose();
    _days.dispose();
    _detail.dispose();
    _supplier.dispose();
    _ledgerSearch.dispose();
    for (final line in _receiptLines) {
      line.dispose();
    }
    super.dispose();
  }

  bool get _isReceipt =>
      _category == ExpenseCategory.feed || _category == ExpenseCategory.other;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  ChartWindow _moneyWindow() {
    if (_ledgerCustom && _ledgerStart != null && _ledgerEnd != null) {
      return windowFor(
        FarmPeriod.year,
        _today,
        customStart: _ledgerStart,
        customEnd: _ledgerEnd,
      );
    }
    return presetWindow(_ledgerPreset, _today);
  }

  Future<void> _pickMoneyRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: _ledgerStart ?? today.subtract(const Duration(days: 29)),
        end: _ledgerEnd ?? today,
      ),
      helpText: 'Choose dates',
      saveText: 'Use these dates',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _ledgerCustom = true;
      _ledgerStart = picked.start;
      _ledgerEnd = picked.end;
    });
  }

  Future<void> _saveExpense() async {
    if (_isReceipt) {
      await _saveReceipt();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    final kilos = double.tryParse(_kilos.text.trim());
    final count = double.tryParse(_quantity.text.trim());
    final record = ExpenseRecord(
      id: newId(),
      happenedOn: _today,
      category: _category,
      amountCedis: amount,
      note: _note.text.trim(),
      itemName: _itemName.text.trim(),
      quantity: _category == ExpenseCategory.feed ? null : count,
      quantityKg: _category == ExpenseCategory.feed ? kilos : null,
      feedType: _category == ExpenseCategory.feed ? _feedType : null,
      animalTag:
          _category == ExpenseCategory.vet &&
              _vetKind.toLowerCase() != 'vaccination'
          ? _animal.text.trim()
          : null,
      people: _category == ExpenseCategory.labour
          ? int.tryParse(_people.text.trim())
          : null,
      days: _category == ExpenseCategory.labour
          ? double.tryParse(_days.text.trim())
          : null,
      litres: _category == ExpenseCategory.fuel ? count : null,
      detail: switch (_category) {
        ExpenseCategory.vet => _vetKind,
        ExpenseCategory.fuel => _fuelType,
        ExpenseCategory.transport ||
        ExpenseCategory.repairs => _detail.text.trim(),
        _ => null,
      },
      supplier: _supplier.text.trim(),
      hasReceipt: _hasReceipt,
      locationId: _location,
      updatedAt: DateTime.now().toUtc(),
    );
    final problem = expenseProblem(record);
    if (problem != null) {
      setState(() {
        _saving = false;
        _error = problem;
      });
      return;
    }
    if (_category == ExpenseCategory.feed && widget.feed != null) {
      final bought = await widget.feed!.buy(
        FeedIngredient(
          id: newId(),
          name: _feedType,
          stockKg: kilos ?? 0,
          unitCost: amount / kilos!,
          supplier: _supplier.text.trim(),
          purchasedOn: _today,
          minimumKg: 0,
        ),
        DateTime.now(),
      );
      if (!mounted) {
        return;
      }
      if (bought != null) {
        setState(() {
          _saving = false;
          _error = bought;
        });
        return;
      }
    }
    final error = await widget.ledger.addExpense(record);
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
      if (error == null) {
        _amount.clear();
        _itemName.clear();
        _quantity.clear();
        _note.clear();
        _kilos.clear();
        _animal.clear();
        _people.clear();
        _days.clear();
        _detail.clear();
        _supplier.clear();
        _hasReceipt = false;
      }
    });
  }

  Future<void> _attachReceipt(ImageSource source) async {
    setState(() {
      _readingReceipt = true;
      _error = null;
    });
    try {
      final photos = await _pickReceiptPhotos(source);
      if (!mounted || photos.isEmpty) {
        return;
      }
      final draft = await ReceiptReader(
        AppConfig.fromEnvironment().geminiApiKey,
      ).readAll(photos);
      if (!mounted) {
        return;
      }
      if (draft != null && draft.items.isNotEmpty) {
        _fillReceipt(draft);
        final problem = _receiptProblem();
        if (problem == null) {
          await _saveReceipt();
          return;
        }
        setState(() {
          _photoCount = photos.length;
          _hasReceipt = true;
          _error = problem;
        });
        return;
      }
      setState(() {
        _photoCount = photos.length;
        _hasReceipt = true;
        _fillSingleDraft(draft);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'The photo could not be opened. Type the expense instead.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _readingReceipt = false);
      }
    }
  }

  Future<List<Uint8List>> _pickReceiptPhotos(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final picked = await ImagePicker().pickMultiImage(
        maxWidth: 1600,
        imageQuality: 70,
        limit: 6,
      );
      final photos = <Uint8List>[];
      for (final photo in picked.take(6)) {
        photos.add(Uint8List.fromList(await photo.readAsBytes()));
      }
      return photos;
    }
    final photos = <Uint8List>[];
    while (photos.length < 6) {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 70,
      );
      if (photo == null) {
        break;
      }
      if (!mounted) {
        break;
      }
      photos.add(Uint8List.fromList(await photo.readAsBytes()));
      if (photos.length >= 6 || !mounted) {
        break;
      }
      final another = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Another photo?'),
          content: Text(
            photos.length == 1
                ? '1 photo ready.'
                : '${photos.length} photos ready.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Done'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Another photo'),
            ),
          ],
        ),
      );
      if (another != true) {
        break;
      }
    }
    return photos;
  }

  void _fillReceipt(ReceiptDraft draft) {
    final previous = [..._receiptLines];
    final feed =
        draft.category == 'feed' ||
        draft.items.every(
          (item) => feedTypes.any(
            (type) => item.name.toLowerCase().contains(type.toLowerCase()),
          ),
        );
    _category = feed ? ExpenseCategory.feed : ExpenseCategory.other;
    if (draft.supplier.isNotEmpty) {
      _supplier.text = draft.supplier;
    }
    _receiptLines = [
      for (final item in draft.items)
        _ReceiptLine.fromItem(item, fallback: allSitesId),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final line in previous) {
        line.dispose();
      }
    });
  }

  String? _receiptProblem() {
    final receiptId = 'check';
    for (final line in _receiptLines) {
      final problem = expenseProblem(_recordForLine(line, receiptId));
      if (problem != null) {
        return problem;
      }
    }
    return null;
  }

  void _fillSingleDraft(ReceiptDraft? draft) {
    if (draft == null || draft.isEmpty) {
      _error = AppConfig.fromEnvironment().geminiApiKey.isEmpty
          ? 'Photos attached. Type the items. Automatic reading needs a Gemini key.'
          : 'The photos could not be read. Type the items.';
      return;
    }
    if (draft.supplier.isNotEmpty) {
      _supplier.text = draft.supplier;
    }
    if (_isReceipt) {
      final line = _receiptLines.first;
      if (draft.amountCedis != null &&
          draft.amountCedis! > 0 &&
          line.amount.text.trim().isEmpty) {
        line.amount.text = draft.amountCedis!.round().toString();
      }
      if (draft.note.isNotEmpty && line.item.text.trim().isEmpty) {
        line.item.text = draft.note;
        line.feedType = _feedMatch(draft.note);
      }
      return;
    }
    if (draft.amountCedis != null && draft.amountCedis! > 0) {
      _amount.text = draft.amountCedis!.round().toString();
    }
    if (draft.note.isNotEmpty && _note.text.trim().isEmpty) {
      _note.text = draft.note;
    }
  }

  ExpenseRecord _recordForLine(_ReceiptLine line, String receiptId) {
    final amount = double.tryParse(line.amount.text.trim()) ?? 0;
    final qty = double.tryParse(line.quantity.text.trim());
    final item = line.item.text.trim();
    return ExpenseRecord(
      id: newId(),
      happenedOn: _today,
      category: _category,
      amountCedis: amount,
      note: _category == ExpenseCategory.other ? item : _note.text.trim(),
      itemName: item,
      quantity: _category == ExpenseCategory.feed ? null : qty,
      quantityKg: _category == ExpenseCategory.feed ? qty : null,
      feedType: _category == ExpenseCategory.feed ? line.feedType : null,
      supplier: _supplier.text.trim(),
      hasReceipt: _photoCount > 0 || _hasReceipt,
      locationId: line.locationId,
      receiptId: receiptId,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _saveReceipt() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final receiptId = newId();
    final records = [
      for (final line in _receiptLines) _recordForLine(line, receiptId),
    ];
    for (final record in records) {
      final problem = expenseProblem(record);
      if (problem != null) {
        setState(() {
          _saving = false;
          _error = problem;
        });
        return;
      }
    }
    for (final record in records) {
      if (record.category == ExpenseCategory.feed && widget.feed != null) {
        final kilos = record.quantityKg ?? 0;
        final bought = await widget.feed!.buy(
          FeedIngredient(
            id: newId(),
            name: record.feedType ?? '',
            stockKg: kilos,
            unitCost: kilos <= 0 ? 0 : record.amountCedis / kilos,
            supplier: record.supplier,
            purchasedOn: _today,
            minimumKg: 0,
          ),
          DateTime.now(),
        );
        if (!mounted) {
          return;
        }
        if (bought != null) {
          setState(() {
            _saving = false;
            _error = bought;
          });
          return;
        }
      }
      final error = await widget.ledger.addExpense(record);
      if (!mounted) {
        return;
      }
      if (error != null) {
        setState(() {
          _saving = false;
          _error = error;
        });
        return;
      }
    }
    final previous = [..._receiptLines];
    _receiptLines = [_ReceiptLine(locationId: allSitesId)];
    setState(() {
      _saving = false;
      _error = null;
      _amount.clear();
      _itemName.clear();
      _quantity.clear();
      _note.clear();
      _kilos.clear();
      _animal.clear();
      _people.clear();
      _days.clear();
      _detail.clear();
      _supplier.clear();
      _hasReceipt = false;
      _photoCount = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final line in previous) {
        line.dispose();
      }
    });
  }

  void _addLine() {
    if (_receiptLines.length >= 12) {
      return;
    }
    setState(() {
      _receiptLines.add(_ReceiptLine(locationId: _receiptLines.last.locationId));
    });
  }

  void _removeLine(int index) {
    final line = _receiptLines.removeAt(index);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
  }

  Future<void> _saveSale() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final kind = switch (_enterprise) {
      Enterprise.dairy => SaleKind.milk,
      Enterprise.poultry => SaleKind.poultry,
      Enterprise.pig ||
      Enterprise.beef ||
      Enterprise.goat ||
      Enterprise.general => SaleKind.livestock,
    };
    final item = _itemName.text.trim();
    final count = double.tryParse(_quantity.text.trim());
    final tag = _saleTag.text.trim();
    final weight = double.tryParse(_saleWeight.text.trim());
    final costs = double.tryParse(_saleCost.text.trim());
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (item.isEmpty) {
      setState(() {
        _saving = false;
        _error = 'Name the item.';
      });
      return;
    }
    if (count == null || count <= 0) {
      setState(() {
        _saving = false;
        _error = 'Enter the quantity.';
      });
      return;
    }
    if (tag.isNotEmpty) {
      if (weight == null || weight <= 0) {
        setState(() {
          _saving = false;
          _error = 'Enter the weight.';
        });
        return;
      }
      if (costs == null || costs < 0) {
        setState(() {
          _saving = false;
          _error = 'Enter the costs.';
        });
        return;
      }
      final sold = await _markSold(tag, weight, amount, costs);
      if (!mounted) {
        return;
      }
      if (sold != null) {
        setState(() {
          _saving = false;
          _error = sold;
        });
        return;
      }
    }
    final error = await widget.ledger.addSale(
      SaleRecord(
        id: newId(),
        happenedOn: _today,
        kind: kind,
        enterprise: _enterprise,
        locationId: farmSites.first.id,
        amountCedis: amount,
        quantity: count,
        itemName: item,
        animalTag: tag,
        weightKg: weight,
        costCedis: costs,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
      if (error == null) {
        _amount.clear();
        _itemName.clear();
        _quantity.clear();
        _saleTag.clear();
        _saleWeight.clear();
        _saleCost.clear();
      }
    });
  }

  Future<String?> _markSold(
    String tag,
    double weight,
    double price,
    double costs,
  ) async {
    final herd = widget.herd;
    if (herd == null) {
      return null;
    }
    Animal? animal;
    for (final row in herd.animals) {
      if (row.tag.toLowerCase() == tag.toLowerCase()) {
        animal = row;
      }
    }
    if (animal == null) {
      return 'That tag is not on the register.';
    }
    if (animal.status != AnimalStatus.onFarm) {
      return 'That animal is already ${animal.status.label.toLowerCase()}.';
    }
    final expected = switch (_enterprise) {
      Enterprise.pig => Species.pig,
      Enterprise.beef || Enterprise.dairy => Species.cattle,
      Enterprise.goat => Species.goat,
      Enterprise.poultry => Species.poultry,
      Enterprise.general => null,
    };
    final matches =
        expected == null ||
        animal.species == expected ||
        (expected == Species.goat && animal.species == Species.sheep);
    if (!matches) {
      return 'That tag is a ${animal.species.singular.toLowerCase()}.';
    }
    return herd.save(
      animal.copyWith(
        status: AnimalStatus.sold,
        updatedAt: DateTime.now().toUtc(),
        saleDate: _today,
        saleWeightKg: weight,
        salePrice: price,
        saleCost: costs,
        weightKg: weight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.ledger,
      builder: (context, _) {
        final theme = Theme.of(context);
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final lines = _moneyLines();
            final selected = _selected(lines);
            final header = <Widget>[
              if (_part == _MoneyPart.expenses)
                ..._expenseBody(theme, wide: wide)
              else
                ..._salesBody(theme, wide: wide),
              ..._tableFilters(lines.length),
              if (lines.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Nothing matches.'),
                  ),
                ),
            ];
            final list = CustomScrollView(
              key: Key('money-list-${_part.name}'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  sliver: SliverList(delegate: SliverChildListDelegate(header)),
                ),
                if (lines.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: PageBox(
                        count: lines.length,
                        height: 360,
                        resetToken:
                            '${_part.name}|${_ledgerFilter.name}|${_ledgerSearch.text}|$_ledgerPreset',
                        header: const _TableHead(),
                        itemBuilder: (context, index) {
                          final line = lines[index];
                          return Column(
                            children: [
                              if (index > 0) const Divider(height: 1),
                              _TableRow(
                                line: line,
                                selected: line.keyId == _selectedLine,
                                onTap: () =>
                                    setState(() => _selectedLine = line.keyId),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!wide && selected != null) ...[
                          _detailPane(selected, scroll: false),
                          const SizedBox(height: 12),
                        ],
                        _chartsCard(),
                      ],
                    ),
                  ),
                ),
              ],
            );
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PartButton(
                          key: const Key('money-expenses'),
                          label: 'Expenses',
                          selected: _part == _MoneyPart.expenses,
                          onTap: () => setState(() {
                            _part = _MoneyPart.expenses;
                            _ledgerFilter = _LedgerFilter.expenses;
                            _error = null;
                            _amount.clear();
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PartButton(
                          key: const Key('money-sales'),
                          label: 'Sales',
                          selected: _part == _MoneyPart.sales,
                          onTap: () => setState(() {
                            _part = _MoneyPart.sales;
                            _ledgerFilter = _LedgerFilter.sales;
                            _error = null;
                            _amount.clear();
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: list),
                            SizedBox(
                              width: 340,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  0,
                                  20,
                                  20,
                                  20,
                                ),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: SingleChildScrollView(
                                    child: _detailPane(selected, scroll: false),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : list,
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _expenseBody(ThemeData theme, {required bool wide}) {
    final month = [
      for (final row in widget.ledger.ledger.expenses)
        if (sameMonth(row.happenedOn, _today)) row,
    ];
    return [
      _formWidth(
        wide: wide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Record an expense', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (!_isReceipt) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final site in expenseSites)
                    ChoiceChip(
                      key: Key('expense-site-${site.id}'),
                      label: Text(site.name),
                      selected: _location == site.id,
                      onSelected: (_) => setState(() => _location = site.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('receipt-camera'),
                    onPressed: _readingReceipt
                        ? null
                        : () => _attachReceipt(ImageSource.camera),
                    child: Text(_readingReceipt ? 'Reading…' : 'Take photo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('receipt-gallery'),
                    onPressed: _readingReceipt
                        ? null
                        : () => _attachReceipt(ImageSource.gallery),
                    child: Text(_readingReceipt ? 'Reading…' : 'Choose photos'),
                  ),
                ),
              ],
            ),
            if (_photoCount > 0) ...[
              const SizedBox(height: 8),
              Text(_photoCount == 1 ? '1 photo' : '$_photoCount photos'),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('expense-supplier'),
              controller: _supplier,
              decoration: const InputDecoration(
                labelText: 'Supplier',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in ExpenseCategory.values)
                  ChoiceChip(
                    key: Key('expense-${category.wire}'),
                    label: Text(category.label),
                    selected: _category == category,
                    onSelected: (_) => setState(() {
                      _category = category;
                      _error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isReceipt)
              ..._receiptFields(theme)
            else ...[
              TextField(
                key: const Key('expense-item-name'),
                controller: _itemName,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Item'),
              ),
              const SizedBox(height: 12),
              ..._categoryFields(theme),
              if (_category != ExpenseCategory.feed) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const Key('expense-quantity'),
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  style: theme.textTheme.headlineSmall,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                key: const Key('expense-amount'),
                controller: _amount,
                keyboardType: TextInputType.number,
                style: theme.textTheme.headlineSmall,
                decoration: const InputDecoration(labelText: 'Cedis'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('expense-note'),
                controller: _note,
                decoration: InputDecoration(
                  labelText: _noteLabel,
                  hintText: 'Optional',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              NoticeBanner(message: _error!, isError: true),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('save-expense'),
              onPressed: _saving ? null : _saveExpense,
              child: Text(
                _saving
                    ? 'Saving…'
                    : _isReceipt
                    ? 'Save receipt'
                    : 'Save expense',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      if (month.isEmpty)
        Text(
          'No expenses this month yet.',
          key: const Key('expense-total'),
          style: theme.textTheme.titleMedium,
        )
      else
        _recentSpend(),
    ];
  }

  Widget _recentSpend() {
    final rows = widget.ledger.ledger.expenses;
    return CardGrid(
      minWidth: 220,
      children: [
        _SpendCard(
          label: 'Today',
          rows: [
            for (final row in rows)
              if (sameDay(row.happenedOn, _today)) row,
          ],
        ),
        _SpendCard(
          label: 'This month',
          rows: [
            for (final row in rows)
              if (sameMonth(row.happenedOn, _today)) row,
          ],
        ),
      ],
    );
  }

  Widget _chartsCard() {
    final ledger = widget.ledger.ledger;
    final window = windowFor(FarmPeriod.year, _today);
    final buckets = moneyBuckets(
      ledger,
      _today,
      FarmPeriod.year,
      window: window,
    );
    final sales = salesByEnterprise(
      ledger,
      _today,
      FarmPeriod.year,
      window: window,
    );
    final costs = expensesByItem(
      ledger,
      _today,
      FarmPeriod.year,
      window: window,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const Key('money-charts'),
        initiallyExpanded: false,
        title: const Text('Sales and expenses'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              children: [
                MoneyTrend(
                  buckets: buckets,
                  showSales: true,
                  showExpenses: true,
                ),
                const SizedBox(height: 12),
                MixDonut(
                  title: 'Where the money went',
                  slices: costs,
                  format: formatCedis,
                ),
                const SizedBox(height: 12),
                MixDonut(
                  title: 'Where the money came from',
                  slices: sales,
                  format: formatCedis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_MoneyLine> _moneyLines() {
    final query = _ledgerSearch.text.trim().toLowerCase();
    final window = _moneyWindow();
    final rows = <_MoneyLine>[
      if (_ledgerFilter != _LedgerFilter.sales)
        for (final row in widget.ledger.ledger.expenses)
          if (_ledgerCategory == null || row.category == _ledgerCategory)
            _MoneyLine.expense(row),
      if (_ledgerFilter != _LedgerFilter.expenses)
        for (final row in widget.ledger.ledger.sales) _MoneyLine.sale(row),
    ];
    final matched = [
      for (final row in rows)
        if (window.contains(row.day) &&
            (query.isEmpty || row.searchText.contains(query)))
          row,
    ]..sort((a, b) => b.day.compareTo(a.day));
    return matched;
  }

  _MoneyLine? _selected(List<_MoneyLine> lines) {
    for (final line in lines) {
      if (line.keyId == _selectedLine) {
        return line;
      }
    }
    return null;
  }

  List<Widget> _tableFilters(int count) {
    final window = _moneyWindow();
    final period = RangeMenu(
      preset: _ledgerPreset,
      custom: _ledgerCustom,
      customLabel: _ledgerStart == null
          ? 'Custom dates'
          : '${formatFarmDate(window.start)} – ${formatFarmDate(window.end)}',
      onPreset: (preset) => setState(() {
        _ledgerCustom = false;
        _ledgerPreset = preset;
      }),
      onCustom: _pickMoneyRange,
      keyPrefix: 'money-period',
    );
    return [
      Text('All records', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(
        count == 1 ? '1 record' : '$count records',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) {
          final chips = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                key: const Key('money-filter-all'),
                label: const Text('All'),
                selected: _ledgerFilter == _LedgerFilter.all,
                onSelected: (_) => setState(() {
                  _ledgerFilter = _LedgerFilter.all;
                }),
              ),
              FilterChip(
                key: const Key('money-filter-expenses'),
                label: const Text('Expenses'),
                selected: _ledgerFilter == _LedgerFilter.expenses,
                onSelected: (_) => setState(() {
                  _ledgerFilter = _LedgerFilter.expenses;
                }),
              ),
              FilterChip(
                key: const Key('money-filter-sales'),
                label: const Text('Sales'),
                selected: _ledgerFilter == _LedgerFilter.sales,
                onSelected: (_) => setState(() {
                  _ledgerFilter = _LedgerFilter.sales;
                  _ledgerCategory = null;
                }),
              ),
            ],
          );
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [chips, const SizedBox(height: 8), period],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: chips),
              const SizedBox(width: 12),
              SizedBox(width: 240, child: period),
            ],
          );
        },
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('money-search'),
              controller: _ledgerSearch,
              decoration: const InputDecoration(
                hintText: 'Search notes, tags, or enterprises',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_ledgerFilter != _LedgerFilter.sales) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<ExpenseCategory?>(
                key: const Key('money-category'),
                initialValue: _ledgerCategory,
                isExpanded: true,
                decoration: farmDropdownDecoration('Category'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  for (final category in ExpenseCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Text(category.label),
                    ),
                ],
                onChanged: (value) => setState(() => _ledgerCategory = value),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
    ];
  }

  Widget _formWidth({required bool wide, required Widget child}) {
    if (!wide) {
      return child;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: child,
      ),
    );
  }

  Widget _detailPane(_MoneyLine? line, {required bool scroll}) {
    final body = line == null
        ? const Text('Select a row to see the full record.')
        : _DetailBody(
            line: line,
            onClose: () => setState(() => _selectedLine = null),
          );
    return Card(
      key: const Key('money-detail'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: scroll ? SingleChildScrollView(child: body) : body,
      ),
    );
  }

  String get _noteLabel {
    return switch (_category) {
      ExpenseCategory.feed => 'Which pen?',
      ExpenseCategory.vet => 'Medicine',
      ExpenseCategory.labour => 'The job',
      ExpenseCategory.transport => 'What moved?',
      ExpenseCategory.fuel => 'Which machine?',
      ExpenseCategory.repairs => 'Anything else?',
      ExpenseCategory.other => 'What was it?',
    };
  }

  List<Widget> _receiptFields(ThemeData theme) {
    return [
      for (var index = 0; index < _receiptLines.length; index++) ...[
        if (index > 0) const Divider(height: 28),
        Text(
          _receiptLines.length == 1 ? 'Item' : 'Item ${index + 1}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final site in expenseSites)
              ChoiceChip(
                key: Key(
                  index == 0
                      ? 'expense-site-${site.id}'
                      : 'expense-site-$index-${site.id}',
                ),
                label: Text(site.name),
                selected: _receiptLines[index].locationId == site.id,
                onSelected: (_) =>
                    setState(() => _receiptLines[index].locationId = site.id),
              ),
          ],
        ),
        if (_category == ExpenseCategory.feed) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in feedTypes)
                ChoiceChip(
                  key: Key(
                    index == 0
                        ? 'expense-feed-${type.toLowerCase().replaceAll(' ', '-')}'
                        : 'expense-feed-$index-${type.toLowerCase().replaceAll(' ', '-')}',
                  ),
                  label: Text(type),
                  selected: _receiptLines[index].feedType == type,
                  onSelected: (_) =>
                      setState(() => _receiptLines[index].feedType = type),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          key: Key(
            index == 0 ? 'expense-item-name' : 'expense-item-name-$index',
          ),
          controller: _receiptLines[index].item,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Item'),
        ),
        const SizedBox(height: 8),
        TextField(
          key: Key(
            index == 0
                ? (_category == ExpenseCategory.feed
                      ? 'expense-kilos'
                      : 'expense-quantity')
                : (_category == ExpenseCategory.feed
                      ? 'expense-kilos-$index'
                      : 'expense-quantity-$index'),
          ),
          controller: _receiptLines[index].quantity,
          keyboardType: TextInputType.number,
          style: theme.textTheme.headlineSmall,
          decoration: InputDecoration(
            labelText: _category == ExpenseCategory.feed ? 'Kilos' : 'Quantity',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: Key(index == 0 ? 'expense-amount' : 'expense-amount-$index'),
          controller: _receiptLines[index].amount,
          keyboardType: TextInputType.number,
          style: theme.textTheme.headlineSmall,
          decoration: const InputDecoration(labelText: 'Cedis'),
        ),
        if (_receiptLines.length > 1)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _removeLine(index),
              child: const Text('Remove item'),
            ),
          ),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const Key('expense-add-item'),
          onPressed: _receiptLines.length >= 12 ? null : _addLine,
          child: const Text('Add another item'),
        ),
      ),
      if (_category == ExpenseCategory.feed) ...[
        const SizedBox(height: 8),
        TextField(
          key: const Key('expense-note'),
          controller: _note,
          decoration: const InputDecoration(
            labelText: 'Which pen?',
            hintText: 'Optional',
          ),
        ),
      ],
    ];
  }

  List<Widget> _categoryFields(ThemeData theme) {
    return switch (_category) {
      ExpenseCategory.feed => [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in feedTypes)
              ChoiceChip(
                key: Key(
                  'expense-feed-${type.toLowerCase().replaceAll(' ', '-')}',
                ),
                label: Text(type),
                selected: _feedType == type,
                onSelected: (_) => setState(() => _feedType = type),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('expense-kilos'),
          controller: _kilos,
          keyboardType: TextInputType.number,
          style: theme.textTheme.headlineSmall,
          decoration: const InputDecoration(labelText: 'Kilos'),
        ),
      ],
      ExpenseCategory.vet => [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in vetKinds)
              ChoiceChip(
                key: Key('expense-vet-${kind.toLowerCase()}'),
                label: Text(kind),
                selected: _vetKind == kind,
                onSelected: (_) => setState(() => _vetKind = kind),
              ),
          ],
        ),
        if (_vetKind.toLowerCase() != 'vaccination') ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('expense-animal'),
            controller: _animal,
            textCapitalization: TextCapitalization.characters,
            style: theme.textTheme.headlineSmall,
            decoration: const InputDecoration(labelText: 'Animal tag'),
          ),
        ],
      ],
      ExpenseCategory.labour => [
        TextField(
          key: const Key('expense-people'),
          controller: _people,
          keyboardType: TextInputType.number,
          style: theme.textTheme.headlineSmall,
          decoration: const InputDecoration(labelText: 'People'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('expense-days'),
          controller: _days,
          keyboardType: TextInputType.number,
          style: theme.textTheme.headlineSmall,
          decoration: const InputDecoration(labelText: 'Days'),
        ),
      ],
      ExpenseCategory.transport => [
        TextField(
          key: const Key('expense-where'),
          controller: _detail,
          decoration: const InputDecoration(labelText: 'Where'),
        ),
      ],
      ExpenseCategory.fuel => [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in fuelTypes)
              ChoiceChip(
                key: Key('expense-fuel-${kind.toLowerCase()}'),
                label: Text(kind),
                selected: _fuelType == kind,
                onSelected: (_) => setState(() => _fuelType = kind),
              ),
          ],
        ),
      ],
      ExpenseCategory.repairs => [
        TextField(
          key: const Key('expense-item'),
          controller: _detail,
          decoration: const InputDecoration(labelText: 'What was repaired?'),
        ),
      ],
      ExpenseCategory.other => const [],
    };
  }

  List<Widget> _salesBody(ThemeData theme, {required bool wide}) {
    final kpis = FarmKpis.evaluate(
      animals: const [],
      ledger: widget.ledger.ledger,
      today: _today,
    );
    final month = [
      for (final row in widget.ledger.ledger.sales)
        if (sameMonth(row.happenedOn, _today)) row,
    ]..sort((a, b) => b.happenedOn.compareTo(a.happenedOn));
    final todaySales = [
      for (final row in widget.ledger.ledger.sales)
        if (sameDay(row.happenedOn, _today)) row,
    ];
    final todayTotal = todaySales.fold<double>(
      0,
      (sum, row) => sum + row.amountCedis,
    );
    return [
      _formWidth(
        wide: wide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sales', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (month.isEmpty)
              const Text('No sales this month yet.', key: Key('sales-total'))
            else
              CardGrid(
                minWidth: 160,
                children: [
                  _SaleCard(label: 'Today', amount: todayTotal),
                  _SaleCard(
                    label: 'This month',
                    amount: kpis.revenue,
                    key: const Key('sales-total'),
                  ),
                  for (final enterprise in Enterprise.values)
                    if (enterprise != Enterprise.general &&
                        (kpis.revenueByEnterprise[enterprise] ?? 0) > 0)
                      _SaleCard(
                        key: Key('sales-${enterprise.wire}'),
                        label: enterprise.label,
                        amount: kpis.revenueByEnterprise[enterprise]!,
                      ),
                ],
              ),
            const SizedBox(height: 20),
            Text('Record a sale', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final enterprise in Enterprise.values)
                  if (enterprise != Enterprise.general)
                    ChoiceChip(
                      key: Key('sale-enterprise-${enterprise.wire}'),
                      label: Text(enterprise.label),
                      selected: _enterprise == enterprise,
                      onSelected: (_) =>
                          setState(() => _enterprise = enterprise),
                    ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sale-item-name'),
              controller: _itemName,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Item'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sale-quantity'),
              controller: _quantity,
              keyboardType: TextInputType.number,
              style: theme.textTheme.headlineSmall,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sale-animal'),
              controller: _saleTag,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Animal tag',
                hintText: 'If this sale is one animal',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sale-weight'),
              controller: _saleWeight,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weight, kg'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sale-cost'),
              controller: _saleCost,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Costs, cedis'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('money-sale-amount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              style: theme.textTheme.headlineSmall,
              decoration: const InputDecoration(labelText: 'Cedis'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              NoticeBanner(message: _error!, isError: true),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('save-sale'),
              onPressed: _saving ? null : _saveSale,
              child: Text(_saving ? 'Saving…' : 'Save sale'),
            ),
          ],
        ),
      ),
    ];
  }
}

class _MoneyLine {
  const _MoneyLine.expense(this.expense) : sale = null;
  const _MoneyLine.sale(this.sale) : expense = null;

  final ExpenseRecord? expense;
  final SaleRecord? sale;

  String get keyId =>
      expense != null ? 'expense-${expense!.id}' : 'sale-${sale!.id}';

  DateTime get day => expense?.happenedOn ?? sale!.happenedOn;

  String get kind => expense != null ? 'Expense' : 'Sale';

  String get title {
    if (expense != null) {
      final name = expense!.itemName.trim();
      final label = name.isEmpty ? expense!.itemLabel : name;
      return '$label · ${siteName(expense!.locationId)}';
    }
    final name = sale!.itemName.trim();
    return name.isEmpty ? sale!.enterprise.label : name;
  }

  double get amount => expense?.amountCedis ?? sale!.amountCedis;

  String get searchText {
    final parts = [
      kind,
      title,
      if (expense != null) ...[
        expense!.category.label,
        expense!.summary,
        expense!.supplier,
        siteName(expense!.locationId),
        expense!.animalTag ?? '',
        expense!.feedType ?? '',
      ],
      if (sale != null) ...[
        sale!.enterprise.label,
        sale!.kind.label,
        sale!.animalTag,
        sale!.itemName,
      ],
    ];
    return parts.join(' ').toLowerCase();
  }
}

class _TableHead extends StatelessWidget {
  const _TableHead();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Date', style: style)),
          Expanded(flex: 5, child: Text('Record', style: style)),
          Expanded(
            flex: 3,
            child: Text('Amount', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.line,
    required this.selected,
    required this.onTap,
  });

  final _MoneyLine line;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? farmLeaf.withValues(alpha: 0.14) : farmPaper,
      child: InkWell(
        key: Key('money-line-${line.keyId}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  formatFarmDate(line.day),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  '${line.kind} · ${line.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  formatCedis(line.amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.line, required this.onClose});

  final _MoneyLine line;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final facts = line.expense != null
        ? _expenseFacts(line.expense!)
        : _saleFacts(line.sale!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(line.title, style: theme.textTheme.titleLarge),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        Text(line.kind, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        for (final fact in facts)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 108,
                  child: Text(
                    fact.$1,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: farmBrown,
                    ),
                  ),
                ),
                Expanded(child: Text(fact.$2)),
              ],
            ),
          ),
      ],
    );
  }
}

List<(String, String)> _expenseFacts(ExpenseRecord row) {
  return [
    ('Date', formatFarmDate(row.happenedOn)),
    ('Category', row.category.label),
    if (row.itemName.trim().isNotEmpty) ('Item', row.itemName.trim()),
    if (row.quantity != null && row.quantity! > 0)
      ('Quantity', _plainDays(row.quantity!)),
    ('Amount', formatCedis(row.amountCedis)),
    if (row.note.trim().isNotEmpty) ('Note', row.note.trim()),
    if (row.feedType != null && row.feedType!.isNotEmpty)
      ('Feed', row.feedType!),
    if (row.quantityKg != null && row.quantityKg! > 0)
      ('Kilos', formatKg(row.quantityKg!)),
    if (row.animalTag != null && row.animalTag!.trim().isNotEmpty)
      ('Animal', row.animalTag!.trim()),
    if (row.people != null) ('People', '${row.people}'),
    if (row.days != null) ('Days', _plainDays(row.days!)),
    if (row.litres != null && row.litres! > 0)
      ('Litres', formatLitres(row.litres!)),
    if (row.detail != null && row.detail!.trim().isNotEmpty)
      ('Detail', row.detail!.trim()),
    if (row.supplier.trim().isNotEmpty) ('Supplier', row.supplier.trim()),
    ('Place', siteName(row.locationId)),
    if (row.hasReceipt) ('Receipt', 'Photo attached'),
  ];
}

List<(String, String)> _saleFacts(SaleRecord row) {
  return [
    ('Date', formatFarmDate(row.happenedOn)),
    ('Enterprise', row.enterprise.label),
    ('Kind', row.kind.label),
    if (row.itemName.trim().isNotEmpty) ('Item', row.itemName.trim()),
    if (row.animalTag.trim().isNotEmpty) ('Animal', row.animalTag.trim()),
    if (row.weightKg != null && row.weightKg! > 0)
      ('Weight', formatKg(row.weightKg!)),
    if (row.costCedis != null) ('Costs', formatCedis(row.costCedis!)),
    ('Amount', formatCedis(row.amountCedis)),
    if (row.quantity != null && row.quantity! > 0)
      ('Quantity', _plainDays(row.quantity!)),
    ('Place', siteName(row.locationId)),
  ];
}

class _SpendCard extends StatelessWidget {
  const _SpendCard({required this.label, required this.rows});

  final String label;
  final List<ExpenseRecord> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = rows.fold<double>(0, (sum, row) => sum + row.amountCedis);
    final byCategory = <ExpenseCategory, double>{};
    for (final row in rows) {
      byCategory[row.category] =
          (byCategory[row.category] ?? 0) + row.amountCedis;
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(formatCedis(total), style: theme.textTheme.headlineSmall),
            for (final category in ExpenseCategory.values)
              if ((byCategory[category] ?? 0) > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: Text(category.label)),
                    Text(formatCedis(byCategory[category]!)),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({super.key, required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(formatCedis(amount), style: theme.textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLine {
  _ReceiptLine({required this.locationId})
    : item = TextEditingController(),
      quantity = TextEditingController(),
      amount = TextEditingController(),
      feedType = feedTypes.first;

  _ReceiptLine.fromItem(ReceiptItem item, {required String fallback})
    : item = TextEditingController(text: item.name),
      quantity = TextEditingController(text: _plainAmount(item.quantity)),
      amount = TextEditingController(text: _plainAmount(item.amountCedis)),
      feedType = _feedMatch(item.name),
      locationId = _siteId(item.site, fallback);

  final TextEditingController item;
  final TextEditingController quantity;
  final TextEditingController amount;
  String feedType;
  String locationId;

  void dispose() {
    item.dispose();
    quantity.dispose();
    amount.dispose();
  }
}

String _plainAmount(double? value) {
  if (value == null || value <= 0) {
    return '';
  }
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toString();
}

String _siteId(String raw, String fallback) {
  final lower = raw.trim().toLowerCase();
  if (lower.isEmpty) {
    return fallback.isEmpty ? allSitesId : fallback;
  }
  if (lower == allSitesId ||
      lower.contains('all') ||
      lower.contains('general') ||
      lower.contains('both')) {
    return allSitesId;
  }
  if (lower.contains('pig')) {
    return 'piggery';
  }
  if (lower.contains('cattle') ||
      lower.contains('poultry') ||
      lower.contains('bird')) {
    return 'cattle_poultry';
  }
  for (final site in expenseSites) {
    if (site.id == lower || site.name.toLowerCase() == lower) {
      return site.id;
    }
  }
  return allSitesId;
}

String _feedMatch(String name) {
  final lower = name.toLowerCase();
  for (final type in feedTypes) {
    if (lower.contains(type.toLowerCase())) {
      return type;
    }
  }
  return feedTypes.first;
}

String _plainDays(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

class _PartButton extends StatelessWidget {
  const _PartButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: selected
          ? FilledButton(onPressed: onTap, child: Text(label))
          : OutlinedButton(onPressed: onTap, child: Text(label)),
    );
  }
}
