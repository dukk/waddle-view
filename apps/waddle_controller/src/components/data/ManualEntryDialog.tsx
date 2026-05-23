import { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Button,
  Checkbox,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  FormControlLabel,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
} from '@mui/material';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import { listJokeCategories, listTriviaCategories } from '@/api/interests';
import type { ContentCategoryOption } from '@/components/OutlookCalendarConfigSection';
import type { SavedDisplay } from '@/storage/displays';
import { DurationInputField } from '@/components/DurationInputField';
import { completeDialogSave } from '@/util/dialogSave';
import {
  manualEntryDialogTitle,
  manualEntryPostPath,
  type ManualEntryKind,
} from '@/util/manualEntryApi';

type CategoryOption = { id: string; label: string };

type Props = {
  open: boolean;
  kind: ManualEntryKind;
  display: SavedDisplay;
  onClose: () => void;
  onSaved: () => void | Promise<void>;
};

function errMsg(e: unknown): string {
  return e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
}

async function fileToBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result;
      if (typeof result !== 'string') {
        reject(new Error('read_failed'));
        return;
      }
      const comma = result.indexOf(',');
      resolve(comma >= 0 ? result.slice(comma + 1) : result);
    };
    reader.onerror = () => reject(reader.error ?? new Error('read_failed'));
    reader.readAsDataURL(file);
  });
}

function localDatetimeToMs(value: string): number {
  return new Date(value).getTime();
}

export function ManualEntryDialog({ open, kind, display, onClose, onSaved }: Props) {
  const [curatorCategories, setCuratorCategories] = useState<ContentCategoryOption[]>([]);
  const [interestCategories, setInterestCategories] = useState<CategoryOption[]>([]);
  const [category, setCategory] = useState('');
  const [altText, setAltText] = useState('');
  const [photographerName, setPhotographerName] = useState('');
  const [durationSeconds, setDurationSeconds] = useState(10);
  const [setup, setSetup] = useState('');
  const [punchline, setPunchline] = useState('');
  const [question, setQuestion] = useState('');
  const [optionA, setOptionA] = useState('');
  const [optionB, setOptionB] = useState('');
  const [optionC, setOptionC] = useState('');
  const [optionD, setOptionD] = useState('');
  const [correctOption, setCorrectOption] = useState('A');
  const [title, setTitle] = useState('');
  const [location, setLocation] = useState('');
  const [description, setDescription] = useState('');
  const [startLocal, setStartLocal] = useState('');
  const [endLocal, setEndLocal] = useState('');
  const [allDay, setAllDay] = useState(false);
  const [quoteText, setQuoteText] = useState('');
  const [quoteAuthor, setQuoteAuthor] = useState('');
  const [quoteCategoryIds, setQuoteCategoryIds] = useState<string[]>([]);
  const [file, setFile] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const usesCuratorCategories =
    kind === 'photos' ||
    kind === 'videos' ||
    kind === 'calendar_events' ||
    kind === 'quoterism_quotes';
  const usesInterestCategories = kind === 'jokes' || kind === 'trivia';
  const usesMultiCuratorCategories = kind === 'quoterism_quotes';

  useEffect(() => {
    if (!open) return;
    setErr(null);
    setFile(null);
    let cancelled = false;
    void (async () => {
      try {
        if (usesCuratorCategories) {
          const res = await apiJson<{ items: ContentCategoryOption[] }>(
            display,
            '/v1/curator/categories',
          );
          if (!cancelled) {
            setCuratorCategories(res.items ?? []);
          }
        } else if (usesInterestCategories) {
          const rows =
            kind === 'jokes'
              ? await listJokeCategories(display)
              : await listTriviaCategories(display);
          if (!cancelled) {
            setInterestCategories(
              rows.map((r) => ({ id: r.id, label: r.label ?? r.id })),
            );
          }
        }
      } catch {
        if (!cancelled) {
          setCuratorCategories([]);
          setInterestCategories([]);
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [display, kind, open, usesCuratorCategories, usesInterestCategories]);

  const categoryOptions: CategoryOption[] = usesCuratorCategories
    ? curatorCategories.map((c) => ({ id: c.id, label: c.label }))
    : interestCategories;

  const save = useCallback(async () => {
    setErr(null);
    if (kind === 'photos' || kind === 'videos') {
      if (!file) {
        setErr('Choose a file.');
        return;
      }
      if (!category.trim()) {
        setErr('Choose a category.');
        return;
      }
    }
    if (kind === 'jokes' || kind === 'trivia') {
      if (!category.trim()) {
        setErr('Choose a category.');
        return;
      }
    }
    if (kind === 'calendar_events') {
      if (!title.trim()) {
        setErr('Title is required.');
        return;
      }
      if (!startLocal || !endLocal) {
        setErr('Start and end are required.');
        return;
      }
      if (!category.trim()) {
        setErr('Choose a category.');
        return;
      }
    }
    if (kind === 'quoterism_quotes') {
      if (!quoteText.trim()) {
        setErr('Quote text is required.');
        return;
      }
    }

    setSaving(true);
    try {
      const path = manualEntryPostPath(kind);
      let body: Record<string, unknown>;

      if (kind === 'photos') {
        body = {
          category,
          bytes_base64: await fileToBase64(file!),
          content_type: file!.type || 'image/jpeg',
          alt_text: altText,
          photographer_name: photographerName,
        };
      } else if (kind === 'videos') {
        body = {
          category,
          bytes_base64: await fileToBase64(file!),
          content_type: file!.type || 'video/mp4',
          duration_seconds: durationSeconds,
          alt_text: altText,
          photographer_name: photographerName,
        };
      } else if (kind === 'jokes') {
        body = { category_id: category, setup, punchline };
      } else if (kind === 'trivia') {
        body = {
          category_id: category,
          question,
          option_a: optionA,
          option_b: optionB,
          option_c: optionC,
          option_d: optionD,
          correct_option: correctOption,
        };
      } else if (kind === 'quoterism_quotes') {
        body = {
          text: quoteText,
          author_name: quoteAuthor,
          category_ids: quoteCategoryIds,
        };
      } else {
        body = {
          title,
          start_ms: localDatetimeToMs(startLocal),
          end_ms: localDatetimeToMs(endLocal),
          all_day: allDay,
          category_id: category,
          location,
          description,
        };
      }

      const res = await apiFetch(display, path, {
        method: 'POST',
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        const text = await res.text();
        setErr(text || `HTTP ${res.status}`);
        return;
      }
      await completeDialogSave(onSaved, onClose);
    } catch (e) {
      setErr(errMsg(e));
    } finally {
      setSaving(false);
    }
  }, [
    kind,
    display,
    category,
    file,
    altText,
    photographerName,
    durationSeconds,
    setup,
    punchline,
    question,
    optionA,
    optionB,
    optionC,
    optionD,
    correctOption,
    title,
    startLocal,
    endLocal,
    allDay,
    location,
    description,
    quoteText,
    quoteAuthor,
    quoteCategoryIds,
    onSaved,
    onClose,
  ]);

  return (
    <Dialog open={open} onClose={saving ? undefined : onClose} maxWidth="sm" fullWidth>
      <DialogTitle>{manualEntryDialogTitle(kind)}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 1 }}>
          {(kind === 'photos' || kind === 'videos') && (
            <Button variant="outlined" component="label" disabled={saving}>
              {file ? file.name : 'Choose file'}
              <input
                type="file"
                hidden
                accept={
                  kind === 'photos'
                    ? 'image/jpeg,image/png,image/webp'
                    : 'video/mp4,video/webm,video/quicktime'
                }
                onChange={(e) => setFile(e.target.files?.[0] ?? null)}
              />
            </Button>
          )}

          {usesMultiCuratorCategories ? (
            <FormControl fullWidth size="small">
              <InputLabel id="manual-entry-quote-categories-label">Categories (optional)</InputLabel>
              <Select
                labelId="manual-entry-quote-categories-label"
                label="Categories (optional)"
                multiple
                value={quoteCategoryIds}
                onChange={(e) => {
                  const v = e.target.value;
                  setQuoteCategoryIds(typeof v === 'string' ? v.split(',') : v);
                }}
                disabled={saving}
                renderValue={(selected) =>
                  selected
                    .map((id) => categoryOptions.find((c) => c.id === id)?.label ?? id)
                    .join(', ')
                }
              >
                {categoryOptions.map((c) => (
                  <MenuItem key={c.id} value={c.id}>
                    {c.label}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          ) : !usesMultiCuratorCategories ? (
            <FormControl fullWidth size="small">
              <InputLabel id="manual-entry-category-label">Category</InputLabel>
              <Select
                labelId="manual-entry-category-label"
                label="Category"
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                disabled={saving}
              >
                {categoryOptions.map((c) => (
                  <MenuItem key={c.id} value={c.id}>
                    {c.label}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          ) : null}

          {kind === 'videos' ? (
            <DurationInputField
              label="Duration"
              valueSeconds={durationSeconds}
              onChange={setDurationSeconds}
              allowedUnits={['sec', 'min', 'hr']}
              minSeconds={1}
              disabled={saving}
            />
          ) : null}

          {(kind === 'photos' || kind === 'videos') && (
            <>
              <TextField
                label="Alt text"
                size="small"
                fullWidth
                value={altText}
                onChange={(e) => setAltText(e.target.value)}
                disabled={saving}
              />
              <TextField
                label="Photographer / credit"
                size="small"
                fullWidth
                value={photographerName}
                onChange={(e) => setPhotographerName(e.target.value)}
                disabled={saving}
              />
            </>
          )}

          {kind === 'jokes' ? (
            <>
              <TextField
                label="Setup"
                size="small"
                fullWidth
                multiline
                minRows={2}
                value={setup}
                onChange={(e) => setSetup(e.target.value)}
                disabled={saving}
              />
              <TextField
                label="Punchline"
                size="small"
                fullWidth
                multiline
                minRows={2}
                value={punchline}
                onChange={(e) => setPunchline(e.target.value)}
                disabled={saving}
              />
            </>
          ) : null}

          {kind === 'trivia' ? (
            <>
              <TextField
                label="Question"
                size="small"
                fullWidth
                multiline
                minRows={2}
                value={question}
                onChange={(e) => setQuestion(e.target.value)}
                disabled={saving}
              />
              <TextField
                label="Option A"
                size="small"
                fullWidth
                value={optionA}
                onChange={(e) => setOptionA(e.target.value)}
                disabled={saving}
              />
              <TextField
                label="Option B"
                size="small"
                fullWidth
                value={optionB}
                onChange={(e) => setOptionB(e.target.value)}
                disabled={saving}
              />
              <TextField
                label="Option C"
                size="small"
                fullWidth
                value={optionC}
                onChange={(e) => setOptionC(e.target.value)}
                disabled={saving}
              />
              <TextField
                label="Option D"
                size="small"
                fullWidth
                value={optionD}
                onChange={(e) => setOptionD(e.target.value)}
                disabled={saving}
              />
              <FormControl fullWidth size="small">
                <InputLabel id="manual-entry-correct-label">Correct answer</InputLabel>
                <Select
                  labelId="manual-entry-correct-label"
                  label="Correct answer"
                  value={correctOption}
                  onChange={(e) => setCorrectOption(e.target.value)}
                  disabled={saving}
                >
                  {(['A', 'B', 'C', 'D'] as const).map((k) => (
                    <MenuItem key={k} value={k}>
                      {k}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </>
          ) : null}

          {kind === 'quoterism_quotes' ? (
            <>
              <TextField
                label="Quote"
                size="small"
                fullWidth
                multiline
                minRows={3}
                value={quoteText}
                onChange={(e) => setQuoteText(e.target.value)}
                disabled={saving}
              />
              <TextField
                label="Author"
                size="small"
                fullWidth
                value={quoteAuthor}
                onChange={(e) => setQuoteAuthor(e.target.value)}
                disabled={saving}
              />
            </>
          ) : null}

          {kind === 'calendar_events' ? (
            <>
              <TextField
                label="Title"
                size="small"
                fullWidth
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                disabled={saving}
              />
              <TextField
                label="Start"
                type="datetime-local"
                size="small"
                fullWidth
                value={startLocal}
                onChange={(e) => setStartLocal(e.target.value)}
                InputLabelProps={{ shrink: true }}
                disabled={saving}
              />
              <TextField
                label="End"
                type="datetime-local"
                size="small"
                fullWidth
                value={endLocal}
                onChange={(e) => setEndLocal(e.target.value)}
                InputLabelProps={{ shrink: true }}
                disabled={saving}
              />
              <FormControlLabel
                control={
                  <Checkbox
                    checked={allDay}
                    onChange={(e) => setAllDay(e.target.checked)}
                    disabled={saving}
                  />
                }
                label="All day"
              />
              <TextField
                label="Location"
                size="small"
                fullWidth
                value={location}
                onChange={(e) => setLocation(e.target.value)}
                disabled={saving}
              />
              <TextField
                label="Description"
                size="small"
                fullWidth
                multiline
                minRows={2}
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                disabled={saving}
              />
            </>
          ) : null}

          {err ? <Alert severity="error">{err}</Alert> : null}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={saving}>
          Cancel
        </Button>
        <Button variant="contained" disabled={saving} onClick={() => void save()}>
          {saving ? 'Saving…' : 'Add'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
