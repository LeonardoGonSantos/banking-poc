using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Serilog;

namespace BankingApi.Middleware;

public class GlobalExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        // Tratar erros de JSON inválido / Bad Request
        if (exception is BadHttpRequestException || exception is System.Text.Json.JsonException)
        {
            Log.Warning("Invalid request data: {Message}", exception.Message);

            var problemDetails = new ProblemDetails
            {
                Status = StatusCodes.Status400BadRequest,
                Title = "Invalid Request",
                Detail = "The request body contains invalid data or format."
            };

            httpContext.Response.StatusCode = problemDetails.Status.Value;
            await httpContext.Response.WriteAsJsonAsync(problemDetails, cancellationToken);

            return true; // Erro tratado
        }

        // Outros erros não tratados (continuam sendo logados como Error pelo Serilog/ASP.NET)
        Log.Error(exception, "An unhandled exception occurred");
        
        var errorResponse = new ProblemDetails
        {
            Status = StatusCodes.Status500InternalServerError,
            Title = "Server Error",
            Detail = "An internal server error has occurred."
        };

        httpContext.Response.StatusCode = errorResponse.Status.Value;
        await httpContext.Response.WriteAsJsonAsync(errorResponse, cancellationToken);

        return true;
    }
}

