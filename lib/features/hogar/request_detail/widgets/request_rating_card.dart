import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_theme.dart';

/// Tarjeta interactiva para calificar al recolector ambiental (RF-12).
/// Permite asignar de 1 a 5 estrellas, ingresar comentarios y enviar la reseña.
class RequestRatingCard extends StatefulWidget {
  const RequestRatingCard({
    super.key,
    required this.collectorName,
    required this.isSubmitting,
    required this.onSubmitRating,
    this.existingRating,
    this.existingFeedback,
  });

  final String collectorName;
  final bool isSubmitting;
  final Future<void> Function(int rating, String? feedback) onSubmitRating;
  final int? existingRating;
  final String? existingFeedback;

  @override
  State<RequestRatingCard> createState() => _RequestRatingCardState();
}

class _RequestRatingCardState extends State<RequestRatingCard> {
  int _selectedRating = 5;
  final _feedbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingRating != null) {
      _selectedRating = widget.existingRating!;
    }
    if (widget.existingFeedback != null) {
      _feedbackController.text = widget.existingFeedback!;
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAlreadyRated = widget.existingRating != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAlreadyRated ? LivoraColors.mint : Colors.amber.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isAlreadyRated
                      ? LivoraColors.mint.withValues(alpha: 0.25)
                      : Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAlreadyRated ? Icons.verified_rounded : Icons.star_rounded,
                  color: isAlreadyRated ? LivoraColors.forest : Colors.amber.shade800,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAlreadyRated ? 'Servicio Calificado' : 'Califica a tu Recolector',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                    Text(
                      'Recolector: ${widget.collectorName}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAlreadyRated)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: LivoraColors.mint.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(
                        '${widget.existingRating}/5',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.forest,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Selector de Estrellas
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                final isFilled = starIndex <= (widget.existingRating ?? _selectedRating);

                return InkWell(
                  onTap: isAlreadyRated || widget.isSubmitting
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedRating = starIndex);
                        },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(
                      isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 36,
                      color: isFilled ? Colors.amber.shade500 : Colors.grey.shade300,
                    ),
                  ),
                );
              }),
            ),
          ),

          if (!isAlreadyRated) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _feedbackController,
              enabled: !widget.isSubmitting,
              maxLines: 2,
              maxLength: 250,
              decoration: InputDecoration(
                hintText: '¿Qué tal fue la atención y puntualidad? (Opcional)',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                contentPadding: const EdgeInsets.all(12),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: LivoraColors.forest),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: LivoraColors.forest,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: widget.isSubmitting
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        await widget.onSubmitRating(
                          _selectedRating,
                          _feedbackController.text.trim().isNotEmpty
                              ? _feedbackController.text.trim()
                              : null,
                        );
                      },
                icon: widget.isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  widget.isSubmitting ? 'Enviando...' : 'Enviar Calificación',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ] else if (widget.existingFeedback != null && widget.existingFeedback!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '"${widget.existingFeedback}"',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
