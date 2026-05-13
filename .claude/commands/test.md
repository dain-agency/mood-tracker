---
description: Write or run tests for a file or module
argument-hint: [file path or 'run' to execute tests]
---

# Test: $ARGUMENTS

## If Running Tests

```bash
# Run all tests
npm test

# Run tests for specific file
npm test -- --grep "ModuleName"

# Run with coverage
npm test -- --coverage

# Run in watch mode
npm test -- --watch
```

## If Writing Tests for a File

### Step 1: Identify Test Location

| Source File | Test File Location |
|-------------|-------------------|
| `src/modules/residents/ResidentCard.tsx` | `src/modules/residents/__tests__/ResidentCard.test.tsx` |
| `src/modules/residents/useResident.ts` | `src/modules/residents/__tests__/useResident.test.ts` |
| `src/modules/residents/resident.service.ts` | `src/modules/residents/__tests__/resident.service.test.ts` |
| `packages/utils/formatDate.ts` | `packages/utils/__tests__/formatDate.test.ts` |

### Step 2: Create Test File with Proper Structure

#### For nextjs Components
```typescript
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ResidentCard } from '../ResidentCard'

// Mock dependencies
vi.mock('@/services/api', () => ({
  fetchResident: vi.fn(),
}))

describe('ResidentCard', () => {
  const defaultProps = {
    resident: {
      id: '1',
      name: 'John Doe',
      roomNumber: 101,
      status: 'active' as const,
    },
    onEdit: vi.fn(),
  }

  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('rendering', () => {
    it('displays resident name', () => {
      render(<ResidentCard {...defaultProps} />)
      expect(screen.getByText('John Doe')).toBeInTheDocument()
    })

    it('displays room number', () => {
      render(<ResidentCard {...defaultProps} />)
      expect(screen.getByText(/Room 101/)).toBeInTheDocument()
    })

    it('shows active status badge', () => {
      render(<ResidentCard {...defaultProps} />)
      expect(screen.getByText('active')).toHaveClass('badge-success')
    })
  })

  describe('interactions', () => {
    it('calls onEdit when edit button clicked', async () => {
      const user = userEvent.setup()
      render(<ResidentCard {...defaultProps} />)
      
      await user.click(screen.getByRole('button', { name: /edit/i }))
      
      expect(defaultProps.onEdit).toHaveBeenCalledWith('1')
    })
  })

  describe('edge cases', () => {
    it('handles missing optional fields', () => {
      const props = {
        ...defaultProps,
        resident: { ...defaultProps.resident, roomNumber: undefined },
      }
      render(<ResidentCard {...props} />)
      expect(screen.queryByText(/Room/)).not.toBeInTheDocument()
    })
  })
})
```

#### For Hooks
```typescript
import { renderHook, act, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useResident } from '../useResident'
import * as api from '@/services/api'

vi.mock('@/services/api')

const createWrapper = () => {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  })
  return ({ children }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  )
}

describe('useResident', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('returns loading state initially', () => {
    vi.mocked(api.fetchResident).mockImplementation(() => new Promise(() => {}))
    
    const { result } = renderHook(() => useResident('1'), {
      wrapper: createWrapper(),
    })
    
    expect(result.current.isLoading).toBe(true)
    expect(result.current.data).toBeUndefined()
  })

  it('returns resident data on success', async () => {
    const mockResident = { id: '1', name: 'John' }
    vi.mocked(api.fetchResident).mockResolvedValue(mockResident)
    
    const { result } = renderHook(() => useResident('1'), {
      wrapper: createWrapper(),
    })
    
    await waitFor(() => {
      expect(result.current.data).toEqual(mockResident)
    })
  })

  it('returns error state on failure', async () => {
    vi.mocked(api.fetchResident).mockRejectedValue(new Error('Not found'))
    
    const { result } = renderHook(() => useResident('1'), {
      wrapper: createWrapper(),
    })
    
    await waitFor(() => {
      expect(result.current.error).toBeDefined()
    })
  })
})
```

#### For Services
```typescript
import { describe, it, expect, vi, beforeEach } from '{{testing_framework}}'
import { residentService } from '../resident.service'
import { db } from '@/lib/db'

vi.mock('@/lib/db')

describe('residentService', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('getById', () => {
    it('returns resident when found', async () => {
      const mockResident = { id: '1', name: 'John' }
      vi.mocked(db.resident.findUnique).mockResolvedValue(mockResident)
      
      const result = await residentService.getById('1')
      
      expect(result).toEqual(mockResident)
      expect(db.resident.findUnique).toHaveBeenCalledWith({
        where: { id: '1' },
      })
    })

    it('throws when resident not found', async () => {
      vi.mocked(db.resident.findUnique).mockResolvedValue(null)
      
      await expect(residentService.getById('999'))
        .rejects.toThrow('Resident not found')
    })

    it('throws on database error', async () => {
      vi.mocked(db.resident.findUnique).mockRejectedValue(new Error('DB Error'))
      
      await expect(residentService.getById('1'))
        .rejects.toThrow('DB Error')
    })
  })

  describe('create', () => {
    it('creates resident with valid data', async () => {
      const input = { name: 'John', roomNumber: 101 }
      const created = { id: '1', ...input }
      vi.mocked(db.resident.create).mockResolvedValue(created)
      
      const result = await residentService.create(input)
      
      expect(result).toEqual(created)
    })

    it('validates required fields', async () => {
      await expect(residentService.create({ name: '' }))
        .rejects.toThrow('Name is required')
    })
  })
})
```

#### For Utility Functions
```typescript
import { describe, it, expect } from '{{testing_framework}}'
import { formatDate, formatCurrency, truncate } from '../formatters'

describe('formatDate', () => {
  it('formats ISO date to readable format', () => {
    expect(formatDate('2024-01-15T10:30:00Z')).toBe('15 Jan 2024')
  })

  it('handles Date objects', () => {
    expect(formatDate(new Date('2024-01-15'))).toBe('15 Jan 2024')
  })

  it('returns empty string for null/undefined', () => {
    expect(formatDate(null)).toBe('')
    expect(formatDate(undefined)).toBe('')
  })

  it('throws for invalid date strings', () => {
    expect(() => formatDate('not-a-date')).toThrow('Invalid date')
  })
})

describe('formatCurrency', () => {
  it('formats number as GBP', () => {
    expect(formatCurrency(1234.56)).toBe('\u00a31,234.56')
  })

  it('handles zero', () => {
    expect(formatCurrency(0)).toBe('\u00a30.00')
  })

  it('handles negative numbers', () => {
    expect(formatCurrency(-50)).toBe('-\u00a350.00')
  })
})
```

### Step 3: Test Coverage Requirements

| Category | Must Test |
|----------|----------|
| Happy path | Normal successful operation |
| Error cases | Invalid input, API failures, edge cases |
| Null/undefined | Handle missing optional data |
| Boundaries | Empty arrays, max lengths, zero values |
| User interactions | Clicks, form submissions, keyboard events |
| Loading states | Async operations in progress |
| Error states | Failed operations, retry logic |

### Step 4: Run and Verify

```bash
# Run the specific test file
npm test -- ResidentCard.test.tsx

# Check coverage for the module
npm test -- --coverage --collectCoverageFrom="src/modules/residents/**/*.{ts,tsx}"
```

---

Now handle: $ARGUMENTS