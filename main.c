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

    // Attempt to find out where we are loaded in memory, so I can hook up a debugger to it.
    // Sadly it generatates an exception: Type - 06(#UD - Invalid Opcode) with RIP = 0xB0000.
    Status = uefi_call_wrapper(BS->HandleProtocol,
                               3,
                               ImageHandle,
                               &LoadedImageProtocol,
                               &loaded_image);

    Print(L"Loaded image!\n");

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