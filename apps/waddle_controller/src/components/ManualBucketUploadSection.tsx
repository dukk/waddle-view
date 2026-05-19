import { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  FormControl,
  FormControlLabel,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import Checkbox from '@mui/material/Checkbox';
import { apiFetch, apiJson, ApiError } from '@/api/client';
import { listJokeCategories, listTriviaCategories } from '@/api/interests';
import type { SavedDisplay } from '@/storage/displays';
import {
  kCalendarBucketIntegrationType,
  kJokeBucketIntegrationType,
  kPhotoBucketIntegrationType,
  kTriviaBucketIntegrationType,
  kVideoBucketIntegrationType,
  manualBucketUploadPath,
} from '@/util/manualBucketIntegration';
import type { ContentCategoryOption } from '@/components/OutlookCalendarConfigSection';

type CategoryOption = { id: string; label: string };

type Props = {
  display: SavedDisplay;
  integrationId: string;
  integrationType: string;
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

export function ManualBucketUploadSection({
  display,
  integrationId,
  integrationType,
}: Props) {
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
  const [file, setFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const usesCuratorCategories =
    integrationType === kPhotoBucketIntegrationType ||
    integrationType === kVideoBucketIntegrationType ||
    integrationType === kCalendarBucketIntegrationType;

  const usesInterestCategories =
    integrationType === kJokeBucketIntegrationType ||
    integrationType === kTriviaBucketIntegrationType;

  useEffect(() => {
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
            integrationType === kJokeBucketIntegrationType
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
  }, [display, integrationType, usesCuratorCategories, usesInterestCategories]);

  const submit = useCallback(async () => {
    setErr(null);
    setSuccess(null);
    setBusy(true);
    try {
      const path = manualBucketUploadPath(integrationId, integrationType);
      let body: Record<string, unknown>;

      if (integrationType === kPhotoBucketIntegrationType) {
        if (!file) {
          setErr('Choose an image file.');
          return;
        }
        body = {
          category,
          bytes_base64: await fileToBase64(file),
          content_type: file.type || 'image/jpeg',
          alt_text: altText,
          photographer_name: photographerName,
        };
      } else if (integrationType === kVideoBucketIntegrationType) {
        if (!file) {
          setErr('Choose a video file.');
          return;
        }
        body = {
          category,
          bytes_base64: await fileToBase64(file),
          content_type: file.type || 'video/mp4',
          duration_seconds: durationSeconds,
          alt_text: altText,
          photographer_name: photographerName,
        };
      } else if (integrationType === kJokeBucketIntegrationType) {
        body = {
          category_id: category,
          setup,
          punchline,
        };
      } else if (integrationType === kTriviaBucketIntegrationType) {
        body = {
          category_id: category,
          question,
          option_a: optionA,
          option_b: optionB,
          option_c: optionC,
          option_d: optionD,
          correct_option: correctOption,
        };
      } else if (integrationType === kCalendarBucketIntegrationType) {
        if (!startLocal || !endLocal) {
          setErr('Start and end are required.');
          return;
        }
        body = {
          title,
          start_ms: localDatetimeToMs(startLocal),
          end_ms: localDatetimeToMs(endLocal),
          all_day: allDay,
          category_id: category,
          location,
          description,
        };
      } else {
        setErr('Unsupported bucket type.');
        return;
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
      const parsed = (await res.json()) as { id?: string };
      setSuccess(parsed.id ? `Created ${parsed.id}` : 'Created.');
      setFile(null);
    } catch (e) {
      setErr(errMsg(e));
    } finally {
      setBusy(false);
    }
  }, [
    integrationId,
    integrationType,
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
  ]);

  const categoryOptions: CategoryOption[] = usesCuratorCategories
    ? curatorCategories.map((c) => ({ id: c.id, label: c.label }))
    : interestCategories;

  return (
    <Stack spacing={2}>
      <Typography variant="subtitle2">Add content</Typography>
      <Typography variant="body2" color="text.secondary">
        Upload or enter items manually. They appear in the catalog and on slides when
        your curator program includes this content.
      </Typography>

      {(integrationType === kPhotoBucketIntegrationType ||
        integrationType === kVideoBucketIntegrationType) && (
        <Button variant="outlined" component="label" disabled={busy}>
          {file ? file.name : 'Choose file'}
          <input
            type="file"
            hidden
            accept={
              integrationType === kPhotoBucketIntegrationType
                ? 'image/jpeg,image/png,image/webp'
                : 'video/mp4,video/webm,video/quicktime'
            }
            onChange={(e) => setFile(e.target.files?.[0] ?? null)}
          />
        </Button>
      )}

      <FormControl fullWidth size="small">
        <InputLabel id="bucket-category-label">Category</InputLabel>
        <Select
          labelId="bucket-category-label"
          label="Category"
          value={category}
          onChange={(e) => setCategory(e.target.value)}
        >
          {categoryOptions.map((c) => (
            <MenuItem key={c.id} value={c.id}>
              {c.label}
            </MenuItem>
          ))}
        </Select>
      </FormControl>

      {integrationType === kVideoBucketIntegrationType ? (
        <TextField
          label="Duration (seconds)"
          type="number"
          size="small"
          fullWidth
          value={durationSeconds}
          onChange={(e) => setDurationSeconds(Number(e.target.value) || 0)}
        />
      ) : null}

      {(integrationType === kPhotoBucketIntegrationType ||
        integrationType === kVideoBucketIntegrationType) && (
        <>
          <TextField
            label="Alt text"
            size="small"
            fullWidth
            value={altText}
            onChange={(e) => setAltText(e.target.value)}
          />
          <TextField
            label="Photographer / credit"
            size="small"
            fullWidth
            value={photographerName}
            onChange={(e) => setPhotographerName(e.target.value)}
          />
        </>
      )}

      {integrationType === kJokeBucketIntegrationType ? (
        <>
          <TextField
            label="Setup"
            size="small"
            fullWidth
            multiline
            minRows={2}
            value={setup}
            onChange={(e) => setSetup(e.target.value)}
          />
          <TextField
            label="Punchline"
            size="small"
            fullWidth
            multiline
            minRows={2}
            value={punchline}
            onChange={(e) => setPunchline(e.target.value)}
          />
        </>
      ) : null}

      {integrationType === kTriviaBucketIntegrationType ? (
        <>
          <TextField
            label="Question"
            size="small"
            fullWidth
            multiline
            minRows={2}
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
          />
          <TextField
            label="Option A"
            size="small"
            fullWidth
            value={optionA}
            onChange={(e) => setOptionA(e.target.value)}
          />
          <TextField
            label="Option B"
            size="small"
            fullWidth
            value={optionB}
            onChange={(e) => setOptionB(e.target.value)}
          />
          <TextField
            label="Option C"
            size="small"
            fullWidth
            value={optionC}
            onChange={(e) => setOptionC(e.target.value)}
          />
          <TextField
            label="Option D"
            size="small"
            fullWidth
            value={optionD}
            onChange={(e) => setOptionD(e.target.value)}
          />
          <FormControl fullWidth size="small">
            <InputLabel id="bucket-correct-label">Correct answer</InputLabel>
            <Select
              labelId="bucket-correct-label"
              label="Correct answer"
              value={correctOption}
              onChange={(e) => setCorrectOption(e.target.value)}
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

      {integrationType === kCalendarBucketIntegrationType ? (
        <>
          <TextField
            label="Title"
            size="small"
            fullWidth
            value={title}
            onChange={(e) => setTitle(e.target.value)}
          />
          <TextField
            label="Start"
            type="datetime-local"
            size="small"
            fullWidth
            value={startLocal}
            onChange={(e) => setStartLocal(e.target.value)}
            InputLabelProps={{ shrink: true }}
          />
          <TextField
            label="End"
            type="datetime-local"
            size="small"
            fullWidth
            value={endLocal}
            onChange={(e) => setEndLocal(e.target.value)}
            InputLabelProps={{ shrink: true }}
          />
          <FormControlLabel
            control={
              <Checkbox checked={allDay} onChange={(e) => setAllDay(e.target.checked)} />
            }
            label="All day"
          />
          <TextField
            label="Location"
            size="small"
            fullWidth
            value={location}
            onChange={(e) => setLocation(e.target.value)}
          />
          <TextField
            label="Description"
            size="small"
            fullWidth
            multiline
            minRows={2}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
        </>
      ) : null}

      {err ? <Alert severity="error">{err}</Alert> : null}
      {success ? <Alert severity="success">{success}</Alert> : null}

      <Box>
        <Button variant="contained" disabled={busy} onClick={() => void submit()}>
          {busy ? 'Saving…' : 'Add'}
        </Button>
      </Box>
    </Stack>
  );
}
