import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import {
  MAX_UPLOAD_BYTES,
  PresignedUploadRequestDto,
} from './presigned-upload-request.dto';

const validate = (payload: Record<string, unknown>): string[] => {
  const dto = plainToInstance(PresignedUploadRequestDto, payload);
  return validateSync(dto).map((error) => error.property);
};

describe('PresignedUploadRequestDto', () => {
  const base = { contentType: 'image/jpeg', folder: 'dogs' };

  it('accepts a file at the size cap', () => {
    expect(validate({ ...base, contentLength: MAX_UPLOAD_BYTES })).toEqual([]);
  });

  it('rejects a file above the size cap', () => {
    expect(validate({ ...base, contentLength: MAX_UPLOAD_BYTES + 1 })).toEqual([
      'contentLength',
    ]);
  });

  it('rejects empty, negative and missing sizes', () => {
    expect(validate({ ...base, contentLength: 0 })).toEqual(['contentLength']);
    expect(validate({ ...base, contentLength: -1 })).toEqual(['contentLength']);
    expect(validate(base)).toEqual(['contentLength']);
  });

  it('still rejects unsupported content types and folders', () => {
    expect(
      validate({ ...base, contentType: 'application/pdf', contentLength: 10 }),
    ).toEqual(['contentType']);
    expect(
      validate({ ...base, folder: 'anything', contentLength: 10 }),
    ).toEqual(['folder']);
  });
});
