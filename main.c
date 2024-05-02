#include <efi.h>
#include <efilib.h>

#define CI (ST->ConIn)

EFI_STATUS
EFIAPI
efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
{
    EFI_LOADED_IMAGE *loaded_image = NULL;
    EFI_STATUS Status;

    InitializeLib(ImageHandle, SystemTable);

    Status = Print(L"Powered on!\n");
    if (EFI_ERROR(Status))
    {
        Print(L"Print() errored... %d", Status);
    }

    Status = uefi_call_wrapper(ST->ConOut->OutputString, 1, L"Hello from the wrapper!\n");

    Status = uefi_call_wrapper(BS->HandleProtocol,
                               3,
                               ImageHandle,
                               &LoadedImageProtocol,
                               &loaded_image);
    Print(L"Loaded image!\n"); // This will never be reached
    if (EFI_ERROR(Status))
    {
        Print(L"handleprotocol: %r\n", Status);
    }

    Print(L"Image base: 0x%lx\n", loaded_image->ImageBase);

    volatile int wait = 1;
    while (wait)
    {
        __asm__ __volatile__("pause");
    }

    return EFI_SUCCESS;
}