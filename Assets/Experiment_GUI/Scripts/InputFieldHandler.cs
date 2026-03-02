using TMPro;
using UnityEngine;

public class InputFieldHandler : MonoBehaviour
{
    [Header("References")]
    [SerializeField] private TMP_InputField inputField;
    [SerializeField] private TMP_Text warningText;

    public void ValidateInput()
    {
        if (!InputValidation.TryGetFloat(inputField.text, out float value))
        {
            warningText.text = $"Invalid input: '{inputField.text}' is not a valid number.";
        }
        else
        {
            warningText.text = string.Empty; // Clear warning if input is valid
        }
    }
}
