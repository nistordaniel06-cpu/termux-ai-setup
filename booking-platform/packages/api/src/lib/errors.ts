export class ApiError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export const badRequest = (message: string) => new ApiError(400, message);
export const unauthorized = (message = "Unauthorized") => new ApiError(401, message);
export const forbidden = (message = "Forbidden") => new ApiError(403, message);
export const notFound = (message = "Not found") => new ApiError(404, message);
export const conflict = (message: string) => new ApiError(409, message);
