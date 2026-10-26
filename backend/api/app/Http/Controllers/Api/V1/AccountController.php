<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\DeleteAccountRequest;
use Illuminate\Http\JsonResponse;

class AccountController extends Controller
{
    /**
     * Delete the account and every row it owns. Password-confirmed and final.
     */
    public function destroy(DeleteAccountRequest $request): JsonResponse
    {
        $request->user()->deleteAccount();

        return response()->json(['message' => 'Account and all associated health data deleted.']);
    }
}
